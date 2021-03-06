/**
 * Copyright: Copyright 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop-server/blob/master/LICENSE, MIT License)
 */
module coop.core;

public import coop.core.wisdom: Binder, Category;

import coop.common: SortOrder;

class WisdomModel
{
    /// コンストラクタ
    this(Wisdom w) @safe
    {
        wisdom = w;
        migemo = initMigemo;
    }

    /// Migemo 検索が利用可能かどうかを返す
    @property auto migemoAvailable() const @safe pure nothrow @nogc
    {
        return migemo !is null;
    }

    /// バインダー一覧を返す
    @property auto getBinderCategories() @safe const pure nothrow
    {
        return wisdom.binders;
    }

    /// スキル一覧を返す
    @property auto getSkillCategories() @safe const pure nothrow
    {
        return wisdom.recipeCategories;
    }

    /// レシピ情報を返す
    auto getRecipe(string name) @safe
    {
        return wisdom.recipeFor(name);
    }

    /// アイテム情報を返す
    auto getItem(string name) @safe
    {
        import coop.core.item;

        if (auto i = name in wisdom.itemList)
        {
            return *i;
        }
        else
        {
            import coop.common;
            Item item;
            item.petFoodInfo = [PetFoodType.UNKNOWN: 0];
            return item;
        }
        assert(false);
    }

    /// レシピが収録されているバインダーを返す
    auto getBindersFor(string name) @safe
    {
        return wisdom.bindersFor(name);
    }

    /// アイテムの固有情報を返す
    auto getExtraInfo(string name) @safe
    {
        import std.typecons;
        import coop.core.item;
        import coop.common;

        alias RetType = Tuple!(ItemType, "type", ExtraInfo, "extra");

        if (auto i = name in wisdom.itemList)
        {
            if ((*i).type == ItemType.Others)
            {
                RetType ret;
                ret.type = ItemType.Others;
                return ret;
            }
            else if ((*i).type !in wisdom.extraInfoList ||
                     (*i).name !in wisdom.extraInfoList[(*i).type])
            {
                return RetType.init;
            }
            return RetType((*i).type, wisdom.extraInfoList[(*i).type][(*i).name]);
        }
        else
        {
            return RetType.init;
        }
        assert(false);
    }

    /// 飲食物のバフ効果を返す
    auto getFoodEffect(string name) @safe
    {
        if (auto einfo = name in wisdom.foodEffectList)
        {
            return *einfo;
        }
        else
        {
            import coop.core.item;
            return AdditionalEffect.init;
        }
        assert(false);
    }

    /// binder に収録されているレシピ一覧を返す
    auto getRecipeList(string query, Binder binder,
                       Flag!"useMetaSearch" useMetaSearch, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch = No.useReverseSearch) @safe
    {
        import std.algorithm;
        import std.array;

        auto allRecipes = useMetaSearch ?
                          wisdom.binderList.byValue.joiner.array :
                          wisdom.binderList[cast(string)binder];
        return getQueryResultBase(query, allRecipes, useMetaSearch, useMigemo, useReverseSearch);
    }

    /// スキルカテゴリ category に分類されているレシピ一覧を返す
    auto getRecipeList(string query, Category category,
                       Flag!"useMetaSearch" useMetaSearch, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch,
                       SortOrder order) @safe
    {
        import std.algorithm;
        import std.array;

        auto allRecipes = useMetaSearch ?
                          wisdom.skillList.byValue.map!"a[].array".joiner.array :
                          wisdom.skillList[cast(string)category][].array;
        auto queryResult = getQueryResultBase(query, allRecipes, useMetaSearch, useMigemo, useReverseSearch);
        final switch(order) with(SortOrder)
        {
        case BySkill:
            auto levels(string s) {
                auto arr = wisdom.recipeFor(s).requiredSkills.byKeyValue.map!(a => tuple(a.key, a.value)).array;
                arr.multiSort!("a[0] < b[0]", "a[1] < b[1]");
                return arr;
            }
            auto arr = queryResult.map!(a => tuple(a, levels(a))).array;
            arr.multiSort!("a[1] < b[1]", "a[0] < b[0]");
            return arr.map!"a[0]".array;
        case ByName:
            return queryResult.sort().array;
        case ByDefault:
            assert(false);
        }
    }

    /// query にヒットするレシピ一覧を返す。
    /// Yes.useReverseSearch の場合には、query にヒットするアイテムを材料にするレシピ一覧を返す
    auto getRecipeList(string query, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch) @safe
    {
        return getRecipeList(query, Category.init, Yes.useMetaSearch, useMigemo, useReverseSearch, SortOrder.ByName);
    }

    /// query にヒットするアイテム一覧を返す
    auto getItemList(string query, Flag!"useMigemo" useMigemo, Flag!"canBeProduced" canBeProduced, Flag!"useReverseSearch" fromIngredients) @safe
    in {
        assert(!(!canBeProduced && fromIngredients), "fromIngredients is valid only if canBeProduced == true");
    } body {
        import std.algorithm;
        import std.array;
        import std.range;
        import std.regex;

        auto input = query.replaceAll(ctRegex!r"[ 　]", "");
        auto fun = simpleMatchFun(input, useMigemo);
        if (canBeProduced)
        {
            if (fromIngredients)
            {
                return wisdom.ing2prodList
                    .byPair
                    .filter!(kv => fun(kv[0]))
                    .map!(kv => kv[1][])
                    .joiner
                    .array
                    .sort()
                    .uniq
                    .array;
            }
            else
            {
                return wisdom.rrecipeList
                    .byKey
                    .filter!fun
                    .array;
            }
        }
        else
        {
            assert(!fromIngredients);
            return chain(wisdom.itemList.byKey.array,
                         wisdom.rrecipeList.byKey.array)
                .sort
                .uniq
                .array
                .filter!fun
                .array;
        }
    }

    /// 
    @property auto getDefaultPreference() const @safe pure nothrow
    {
        import coop.core.recipe_graph;
        return RecipeGraph.defaultPreference;
    }

    /// 
    auto getMenuRecipeResult(string[] targets) @safe
    {
        import coop.core.recipe_graph;
        auto graph = new RecipeGraph(targets, wisdom, null);
        return graph.elements;
    }

    /// 
    auto getMenuRecipeResult(int[string] targets, int[string] owned, string[string] preference, RedBlackTree!string terminals) @safe
    {
        import std.array;
        import std.conv;
        import coop.core.recipe_graph;

        foreach(k, v; getDefaultPreference)
        {
            if (k !in preference)
            {
                preference[k] = v;
            }
        }

        auto graph = new RecipeGraph(targets.byKey.array, wisdom, preference);
        return graph.elements(targets, owned, terminals);
    }

    ///
    auto costFor(string item, int[string] procs) @safe
    {
        import coop.core.price;

        return referenceCostFor(item,
                                wisdom.itemList, wisdom.recipeList, wisdom.rrecipeList,
                                wisdom.vendorPriceList, (int[string]).init,
                                procs);
    }

private:
    import std.container;
    import std.traits;
    import std.typecons;
    import coop.core.wisdom;
    import coop.migemo;

    auto getQueryResultBase(string query, string[] allRecipes,
                            Flag!"useMetaSearch" useMetaSearch, Flag!"useMigemo" useMigemo,
                            Flag!"useReverseSearch" useReverseSearch = No.useReverseSearch) @safe
    {
        import std.algorithm;
        import std.array;
        import std.regex;

        auto input = query.replaceAll(ctRegex!r"[ 　]", "");
        auto queryFun = matchFunFor(input, useMigemo, useReverseSearch);

        return allRecipes.filter!queryFun.array;
    }

    auto simpleMatchFun(string query, Flag!"useMigemo" useMigemo) @safe
    {
        import std.regex;
        import std.string;
        if (useMigemo)
        {
            assert(migemo);
            try{
                auto q = migemo.query(query).regex;
                return (string s) @safe => !s.replaceAll(ctRegex!r"[ 　]", "").matchFirst(q).empty;
            } catch(RegexException e) {
                // use default matchFun
            }
        }
        else
        {
            import std.algorithm;
            import std.range;

            return (string s) @safe => !find(s.replaceAll(ctRegex!r"[ 　]", ""), boyerMooreFinder(query)).empty;
        }
        assert(false);
    }

    auto matchFunFor(string query, Flag!"useMigemo" useMigemo, Flag!"useReverseSearch" useReverseSearch = No.useReverseSearch) @safe
    {
        auto fun = simpleMatchFun(query, useMigemo);

        if (useReverseSearch)
        {
            import std.algorithm;
            return (string s) @safe => wisdom.recipeFor(s).ingredients.byKey.any!(ing => fun(ing));
        }
        else
        {
            return (string s) @safe => fun(s);
        }
        assert(false);
    }

    static auto initMigemo() @safe
    {
        import std.file;

        auto info = migemoInfo;

        if (info.lib.exists)
        {
            Migemo m;
            try{
                import std.exception;
                import std.path;

                m = new Migemo(info.lib, info.dict);
                m.load(buildPath("resource", "dict", "moe-dict"));
                enforce(m.isEnable);
            } catch(MigemoException e) {
                m = null;
            }
            return m;
        }
        else
        {
            return null;
        }
        assert(false);
    }

    static auto migemoInfo() @safe nothrow
    {
        import std.algorithm;
        import std.file;
        import std.range;
        import std.typecons;

        alias LibInfo = Tuple!(string, "lib", string, "dict");
        version(Windows)
        {
            version(X86)
            {
                enum candidates = [LibInfo.init];
            }
            else version(X86_64)
            {
                enum candidates = [LibInfo(`migemo.dll`, `resource\dict\dict`)];
            }
        }
        else version(linux)
        {
            import std.format;

            version(X86)
            {
                enum arch = "i386-linux-gnu";
            }
            else
            {
                enum arch = "x86_64-linux-gnu";
            }
            enum candidates = [
                // Arch
                LibInfo("/usr/lib/libmigemo.so", "/usr/share/migemo/utf-8"),
                // Debian/Ubuntu
                LibInfo(format("/usr/lib/%s/libmigemo.so.1", arch), "/usr/share/cmigemo/utf-8"),
                // Fedora
                LibInfo("/usr/lib/libmigemo.so.1", "/usr/share/cmigemo/utf-8"),
                ];
        }
        else version(OSX)
        {
            enum candidates = [LibInfo("/usr/local/opt/cmigemo/lib/libmigemo.dylib",
                                       "/usr/local/opt/cmigemo/share/migemo/utf-8")];
        }
        auto ret = candidates.find!(a => a.lib.exists);
        return ret.empty ? LibInfo.init : ret.front;
    }

    public Wisdom wisdom;
    Migemo migemo;
}
