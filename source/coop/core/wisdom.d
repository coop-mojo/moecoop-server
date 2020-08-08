/**
 * Copyright: Copyright 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop-server/blob/master/LICENSE, MIT License)
 */
module coop.core.wisdom;

import std.typecons;

alias Binder = Typedef!(string, string.init, "binder");
alias Category = Typedef!(string, string.init, "category");

class Wisdom {
    import std.container;

    import coop.core.item;
    import coop.core.recipe;
    import coop.core.vendor;
    import coop.common;

    /// バインダーごとのレシピ名一覧
    string[][string] binderList;

    /// スキルカテゴリごとのレシピ名一覧
    RedBlackTree!string[string] skillList;

    /// レシピ一覧
    Recipe[string] recipeList;

    /// 素材(key)を作成するレシピ名一覧(value)
    RedBlackTree!string[string] rrecipeList;

    /// 材料名(key)を使って生産できるアイテム名一覧(value)
    RedBlackTree!string[string] ing2prodList;

    /// アイテム一覧
    Item[string] itemList;

    /// 飲食バフ一覧
    AdditionalEffect[string] foodEffectList;

    /// アイテム種別ごとの固有情報一覧
    ExtraInfo[string][ItemType] extraInfoList;

    /// 販売員情報
    Vendor[string] vendorList;

    /// アイテムごとの売店での販売価格一覧
    int[string] vendorPriceList;

    this(string baseDir)
    {
        baseDir_ = baseDir;
        reload;
    }

    auto reload()
    {
        import std.algorithm;
        import std.array;

        binderList = readBinderList(baseDir_);
        auto tmp = readRecipeList(baseDir_);
        recipeList = tmp.recipes;
        skillList = tmp.skillList;

        rrecipeList = genRRecipeList(recipeList.values);
        ing2prodList = genIng2ProdList(recipeList.values);
        foodEffectList = readFoodEffectList(baseDir_);

        with(ItemType)
        {
            import std.conv;

            extraInfoList[Food.to!ItemType] = readFoodList(baseDir_).to!(ExtraInfo[string]);
            extraInfoList[Drink.to!ItemType] = readDrinkList(baseDir_).to!(ExtraInfo[string]);
            extraInfoList[Liquor.to!ItemType] = readLiquorList(baseDir_).to!(ExtraInfo[string]);
            extraInfoList[Weapon.to!ItemType] = readWeaponList(baseDir_).to!(ExtraInfo[string]);
            extraInfoList[Armor.to!ItemType] = readArmorList(baseDir_).to!(ExtraInfo[string]);
            extraInfoList[Bullet.to!ItemType] = readBulletList(baseDir_).to!(ExtraInfo[string]);
            extraInfoList[Shield.to!ItemType] = readShieldList(baseDir_).to!(ExtraInfo[string]);
        }
        itemList = readItemList(baseDir_);

        vendorList = readVendorList(baseDir_);
        vendorPriceList = genVendorPriceList(vendorList.values);
    }

    @property auto recipeCategories() @safe const pure nothrow
    {
        import std.algorithm;
        import std.array;

        return skillList.byKey.array.sort.array;
    }

    auto recipesIn(Category name) @safe pure nothrow
    in {
        assert(name in skillList);
    } body {
        return skillList[cast(string)name];
    }

    @property auto binders() @safe const pure nothrow
    {
        import std.algorithm;
        import std.array;

        return binderList.byKey.array.sort.array;
    }

    auto recipesIn(Binder name) @safe pure nothrow
    in {
        assert(name in binderList);
    } body {
        return binderList[cast(string)name];
    }

    auto recipeFor(string recipeName) @safe pure
    {
        return recipeList.get(recipeName, Recipe.init);
    }

    auto bindersFor(string recipeName) @safe pure nothrow
    {
        import std.algorithm;
        import std.range;

        return binders.filter!(b => recipesIn(Binder(b)).canFind(recipeName)).array;
    }

private:
    auto readBinderList(string basedir)
    {
        import std.algorithm;
        import std.exception;
        import std.file;
        import std.path;
        import std.range;

        enforce(basedir.exists);
        enforce(basedir.isDir);

        auto dir = buildPath(basedir, "バインダー");
        if (!dir.exists)
        {
            return typeof(binderList).init;
        }
        return dirEntries(dir, "*.json", SpanMode.breadth)
            .map!readBinders
            .array
            .joiner
            .assocArray;
    }

    auto readRecipeList(string basedir)
    {
        import std.algorithm;
        import std.exception;
        import std.file;
        import std.path;
        import std.range;

        import coop.util;

        enforce(basedir.exists);
        enforce(basedir.isDir);

        alias RetType = Tuple!(typeof(skillList), "skillList",
                               typeof(recipeList), "recipes");
        auto dir = buildPath(basedir, "レシピ");
        if (!dir.exists)
        {
            return RetType.init;
        }

        auto lst = dirEntries(dir, "*.json", SpanMode.breadth)
                   .map!readRecipes
                   .checkedAssocArray;
        auto slist = lst.byKeyValue
                        .map!(kv => tuple(kv.key,
                                          make!(RedBlackTree!string)(kv.value.keys)))
                        .assocArray;
        auto rlist = lst.values
                        .map!"a.byPair"
                        .joiner
                        .assocArray;
        return RetType(slist, rlist);
    }

    auto genRRecipeList(Recipe[] recipes) const pure
    {
        import std.algorithm;

        RedBlackTree!string[string] ret;
        foreach(r; recipes)
        {
            foreach(p; r.products.keys)
            {
                if (p !in ret)
                {
                    ret[p] = make!(RedBlackTree!string)(r.name);
                }
                else
                {
                    ret[p].insert(r.name);
                }
            }
        }
        return ret;
    }

    auto genIng2ProdList(Recipe[] recipes) const pure
    {
        import std.algorithm;

        RedBlackTree!string[string] ret;
        foreach(r; recipes)
        {
            foreach(ip; cartesianProduct(r.ingredients.keys, r.products.keys))
            {
                if (ip[0] !in ret)
                {
                    ret[ip[0]] = make!(RedBlackTree!string)(ip[1]);
                }
                else
                {
                    ret[ip[0]].insert(ip[1]);
                }
            }
        }
        return ret;
    }

    auto readFoodEffectList(string sysBase)
    {
        import std.algorithm;
        import std.exception;
        import std.file;
        import std.path;

        import coop.util;

        enforce(sysBase.exists);
        enforce(sysBase.isDir);

        auto dir = buildPath(sysBase, "飲食バフ");
        if (!dir.exists)
        {
            return typeof(foodEffectList).init;
        }
        return dirEntries(dir, "*.json", SpanMode.breadth)
            .map!readFoodEffects
            .joiner
            .checkedAssocArray;
    }

    auto readVendorList(string sysBase)
    {
        import std.algorithm;
        import std.exception;
        import std.file;
        import std.path;

        import coop.util;

        enforce(sysBase.exists);
        enforce(sysBase.isDir);
        auto dir = buildPath(sysBase, "売店");
        if (!dir.exists)
        {
            return typeof(vendorList).init;
        }
        return ["present", "ancient"].map!(d => buildPath(dir, d))
            .filter!(d => d.exists && d.isDir)
            .map!(d => dirEntries(d, "*.json", SpanMode.breadth))
            .joiner
            .map!readVendors
            .joiner
            .checkedAssocArray;
    }

    auto genVendorPriceList(Vendor[] vendors)
    {
        import std.algorithm;
        import std.range;
        import std.typecons;

        return vendors.map!(v => v.products.byKeyValue)
            .joiner
            .map!(kv => tuple(kv.key, kv.value.price))
            .assocArray;
    }

    /// データが保存してあるパス
    immutable string baseDir_;
}

auto readBinders(string file)
{
    import vibe.data.json;

    import std.algorithm;
    import std.exception;
    import std.file;
    import std.typecons;

    enforce(file.exists);
    return file.readText
               .parseJsonString
               .deserialize!(JsonSerializer, string[][string])
               .byKeyValue
               .map!"tuple(a.key, a.value)";
}

unittest
{
    import std.algorithm;
    import std.exception;
    import std.format;
    import std.range;

    import coop.util;

    auto w = assertNotThrown(new Wisdom(SystemResourceBase));
    auto skillList = ["合成", "料理", "木工", "特殊", "薬調合", "裁縫", "装飾細工", "複合", "醸造", "鍛冶", "複製"];
    assert(w.recipeCategories.length == skillList.length);
    foreach (s; skillList)
    {
        assert(w.recipeCategories.canFind(s), format("`%s` not found in recipe categories", s));
    }

    auto binders = ["QoAクエスト", "アクセサリー", "アクセサリー No.2", "カオス", "家", "家具", "木工", "木工 No.2",
                    "材料/道具", "材料/道具 No.2", "楽器", "罠", "裁縫", "裁縫 No.2", "複製",
                    "鍛冶 No.1", "鍛冶 No.2", "鍛冶 No.3", "鍛冶 No.4", "鍛冶 No.5", "鍛冶 No.6", "鍛冶 No.7",
                    "食べ物", "食べ物 No.2", "食べ物 No.3", "飲み物"];
    assert(w.binders.length == binders.length);
    foreach (b; binders)
    {
        assert(w.binders.canFind(b), format("`%s` not found in binders", b));
    }

    assert(w.recipesIn(Binder("食べ物")).length == 128);
    assert("ロースト スネーク ミート" in w.recipesIn(Category("料理")));

    assert(w.recipeFor("とても美味しい食べ物").name.empty);
    assert(w.recipeFor("ロースト スネーク ミート").ingredients == ["ヘビの肉": 1]);

    assert(w.bindersFor("ロースト スネーク ミート").equal(["食べ物"]));
}

unittest
{
    import std.exception;
    import std.range;

    auto w = assertNotThrown(new Wisdom("."));
    assert(w.binders.empty);
    assert(w.recipeCategories.empty);
}
