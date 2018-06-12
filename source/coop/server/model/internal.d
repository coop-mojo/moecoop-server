/**
 * Copyright: Copyright 2017 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop-server/blob/master/LICENSE, MIT License)
 */
module coop.server.model.internal;

import coop.common;
import coop.core: WisdomModel;
import coop.core.item: Item, Grade,
    FInfo = FoodInfo, WInfo = WeaponInfo, AInfo = ArmorInfo,
    BInfo = BulletInfo, SInfo = ShieldInfo, ExtraInfo;
import coop.core.recipe: Recipe;

class WebModel: ModelAPI
{
    import vibe.data.json;

    this(string path, string msg = "")
    {
        import coop.core.wisdom;
        this.wm = new WisdomModel(new Wisdom(path));
        this.message = msg;
    }

    override @property GetVersionResult getVersion() @safe const
    {
        import coop.util;
        string[string] hash;
        return GetVersionResult(Version);
    }

    override @property GetInformationResult getInformation() @safe const pure nothrow
    {
        auto latest = "v1.2.2";
        auto supported = "v1.2.2";
        return GetInformationResult(message, supported, latest);
    }

    override @property GetBinderCategoriesResult getBinderCategories() @safe const pure nothrow
    {
        import std.algorithm;
        import std.range;

        return typeof(return)(wm.getBinderCategories.map!(b => initBinderLink(b)).array);
    }

    override GetRecipesResult getBinderRecipes(string binder, string query, bool migemo, bool rev, string key, string fs) @safe
    {
        import std.algorithm;
        import std.array;
        import std.typecons;

        import vibe.http.common;

        import coop.core;

        auto fields = fs.split(",");

        binder = binder.replace("_", "/");
        enforceHTTP(getBinderCategories.バインダー一覧.map!"a.バインダー名".canFind(binder),
                    HTTPStatus.notFound, "No such binder");

        auto lst = recipeSort(wm.getRecipeList(query, Binder(binder), No.useMetaSearch,
                                               cast(Flag!"useMigemo")migemo, cast(Flag!"useReverseSearch")rev), key);

        auto toRecipeLink(string r)
        {
            import std.exception;
            auto ret = initRecipeLink(r);
            auto detail = getRecipe(r).ifThrown!HTTPStatusException(RecipeInfo.init).toAssocArray;
            ret.追加情報 = getDetails(detail, fields);
            return ret;
        }
        return typeof(return)(lst.map!toRecipeLink.array);
    }

    override @property GetSkillCategoriesResult getSkillCategories() @safe const pure nothrow
    {
        import std.algorithm;
        import std.range;

        return typeof(return)(wm.getSkillCategories.map!(s => initSkillLink(s)).array);
    }

    override GetRecipesResult getSkillRecipes(string skill, string query, bool migemo, bool rev, string key, string fs) @safe
    {
        import std.algorithm;
        import std.array;
        import std.typecons;

        import vibe.http.common;

        import coop.core;

        auto fields = fs.split(",");

        enforceHTTP(getSkillCategories.スキル一覧.map!"a.スキル名".canFind(skill), HTTPStatus.notFound, "No such skill category");

        auto lst = recipeSort(wm.getRecipeList(query, Category(skill), No.useMetaSearch, cast(Flag!"useMigemo")migemo,
                                               cast(Flag!"useReverseSearch")rev, SortOrder.ByName), key);
        auto toRecipeLink(string r)
        {
            import std.exception;
            auto ret = initRecipeLink(r);
            auto detail = getRecipe(r).ifThrown!HTTPStatusException(RecipeInfo.init).toAssocArray;
            ret.追加情報 = getDetails(detail, fields);
            return ret;
        }
        return typeof(return)(lst.map!toRecipeLink.array);
    }

    override BufferLink[][string] getBuffers() @safe
    {
        import std.algorithm;
        import std.range;

        return ["バフ一覧": wm.wisdom.foodEffectList.byKey.map!(k => initBufferLink(k)).array];
    }

    override GetRecipesResult getRecipes(string query, bool useMigemo, bool useReverseSearch, string key, string fs) @safe
    {
        import std.algorithm;
        import std.range;

        import vibe.http.common;
        auto fields = fs.split(",");

        auto lst = recipeSort(wm.getRecipeList(query, cast(Flag!"useMigemo")useMigemo, cast(Flag!"useReverseSearch")useReverseSearch), key);

        auto toRecipeLink(string r)
        {
            import std.exception;
            auto ret = initRecipeLink(r);
            auto detail = getRecipe(r).ifThrown!HTTPStatusException(RecipeInfo.init).toAssocArray;
            ret.追加情報 = getDetails(detail, fields);
            return ret;
        }
        return typeof(return)(lst.map!toRecipeLink.array);
    }

    override GetItemsResult getItems(string query, bool useMigemo, bool onlyProducts, bool fromIngredients) @safe
    {
        import std.algorithm;
        import std.range;

        import vibe.http.common;

        enforceHTTP(!(!onlyProducts && fromIngredients), HTTPStatus.BadRequest, "from-ingredients is valid only if only-products=true");

        return typeof(return)(wm.getItemList(query, cast(Flag!"useMigemo")useMigemo,
                                             cast(Flag!"canBeProduced")onlyProducts, cast(Flag!"useReverseSearch")fromIngredients)
                                .map!(i => initItemLink(i)).array);
    }

    override RecipeInfo getRecipe(string _recipe) @safe
    {
        import std.array;
        import vibe.http.common;

        _recipe = _recipe.replace("_", "/");
        return initRecipeInfo(enforceHTTP(wm.getRecipe(_recipe), HTTPStatus.notFound, "No such recipe"), wm);
    }

    override ItemInfo getItem(string _item)
    {
        return postItem(_item, (int[string]).init);
    }

    override ItemInfo postItem(string _item, int[string] 調達価格) @safe
    {
        import vibe.http.common;
        auto info = initItemInfo(enforceHTTP(wm.getItem(_item), HTTPStatus.notFound, "No such item"), wm);
        info.参考価格 = wm.costFor(_item, 調達価格);
        return info;
    }

    /*
     * 2種類以上レシピがあるアイテムに関して、レシピ候補の一覧を返す
     */
    override GetMenuRecipeOptionsResult getMenuRecipeOptions() @safe
    {
        import std.algorithm;
        import std.range;
        import std.typecons;

        import vibe.data.json;

        with(typeof(return))
        {
            return typeof(return)(wm.getDefaultPreference
                                    .byKey
                                    .map!(k => RetElem(ItemLink(k),
                                                       wm.wisdom
                                                         .rrecipeList[k][]
                                                         .map!(r => initRecipeLink(r))
                                                         .array))
                                    .array);
        }
    }

    override PostMenuRecipePreparationResult postMenuRecipePreparation(string[] 作成アイテム)
    {
        import std.algorithm;
        import std.range;
        import coop.core.recipe_graph: RI = RecipeInfo;

        auto toMenuRecipeInfo(RI ri)
        {
            import std.exception;
            import vibe.http.common;
            import vibe.data.json;

            auto ret = initRecipeLink(ri.name);
            auto detail = getRecipe(ri.name).ifThrown!HTTPStatusException(RecipeInfo.init);
            ret.追加情報["必要スキル"] = detail.必要スキル.serialize!JsonSerializer;
            ret.追加情報["レシピ必須"] = detail.レシピ必須.serialize!JsonSerializer;
            ret.追加情報["選択レシピグループ"] = ri.parentGroup.serialize!JsonSerializer;
            return ret;
        }

        auto ret = wm.getMenuRecipeResult(作成アイテム);

        return typeof(return)(
            ret.recipes.map!toMenuRecipeInfo.array,
            ret.materials.map!((m) {
                    auto it = initItemLink(m.name);
                    it.追加情報["中間素材"] = (!m.isLeaf).serialize!JsonSerializer;
                    return it;
                }).array);
    }

    override PostMenuRecipeResult postMenuRecipe(int[string] 作成アイテム, int[string] 所持アイテム, string[string] 使用レシピ, string[] 直接調達アイテム)
    {
        import std.algorithm;
        import std.conv;
        import std.range;
        import std.container.rbtree;

        return wm.getMenuRecipeResult(作成アイテム, 所持アイテム, 使用レシピ, new RedBlackTree!string(直接調達アイテム));
    }
private:
    auto getDetails(Json[string] info, string[] fields)
    {
        typeof(info) ret;

        foreach(f; fields)
        {
            if (auto val = f in info)
            {
                ret[f] = *val;
            }
            else
            {
                import vibe.http.common;
                enforceHTTP(false, HTTPStatus.notFound, "No such field '"~f~"'");
            }
        }
        return ret;
    }

    auto recipeSort(string[] rs, string key)
    {
        import std.algorithm;
        import std.array;

        import vibe.http.common;

        switch(key)
        {
        case "skill":{
            import std.typecons;
            auto levels(string s) {
                auto arr = wm.getRecipe(s).requiredSkills.byKeyValue.map!(a => tuple(a.key, a.value)).array;
                arr.multiSort!("a[0] < b[0]", "a[1] < b[1]");
                return arr;
            }
            auto arr = rs.map!(a => tuple(a, levels(a))).array;
            arr.multiSort!("a[1] < b[1]", "a[0] < b[0]");
            return arr.map!"a[0]".array;
        }
        case "name":
            return rs.sort().array;
        case "default":
            return rs;
        default:
            enforceHTTP(false, HTTPStatus.BadRequest, "No such key for 'sort'");
        }
        assert(false);
    }
    WisdomModel wm;
    string message;
}

auto toAssocArray(T)(T info) if (is(T == struct))
{
    import std.traits;
    import vibe.data.json;
    Json[string] ret;

    foreach(fname; FieldNameTuple!T)
    {
        ret[fname] = mixin("info."~fname).serialize!JsonSerializer;
    }
    return ret;
}

auto initBinderLink(string binder) @safe pure nothrow
{
    import std.array;
    return BinderLink(binder, "/binders/"~binder.replace("/", "_")~"/recipes");
}

auto initSkillLink(string skill) @safe pure nothrow
{
    return SkillLink(skill, "/skills/"~skill~"/recipes");
}

auto initSkillNumberLink(string skill, double val) @safe pure nothrow
{
    return SkillNumberLink(skill, "/skills/"~skill~"/recipes", val);
}

auto initItemLink(string item) @safe pure nothrow
{
    ItemLink it;
    it.アイテム名 = item;
    it.詳細 = "/items/"~item;
    return it;
}

auto initRecipeLink(string recipe) @safe pure nothrow
{
    import std.array;
    RecipeLink rl;
    rl.レシピ名 = recipe;
    rl.詳細 = "/recipes/"~recipe.replace("/", "_");
    return rl;
}

auto initBufferLink(string buff) @safe pure nothrow
{
    return BufferLink(buff, "/buffers/"~buff);
}

auto initItemNumberLink(string item, int num) @safe pure nothrow
{
    ItemNumberLink it;
    it.アイテム名 = item;
    it.詳細 = "/items/"~item;
    it.個数 = num;
    return it;
}

auto initRecipeNumberLink(string recipe, int num) @safe pure nothrow
{
    import std.array;
    RecipeNumberLink rl;
    rl.レシピ名 = recipe;
    rl.詳細 = "/recipes/"~recipe.replace("/", "_");
    rl.コンバイン数 = num;
    return rl;
}

auto initRecipeInfo(Recipe r, WisdomModel wm)
{
    import std.algorithm;
    import std.range;

    RecipeInfo ri;
    with(ri)
    {
        レシピ名 = r.name;
        材料 = r.ingredients
                .byKeyValue
                .map!(kv => initItemNumberLink(kv.key, kv.value))
                .array;
        生成物 = r.products
                  .byKeyValue
                  .map!(kv => initItemNumberLink(kv.key, kv.value))
                  .array;
        テクニック = r.techniques;
        必要スキル = r.requiredSkills;
        レシピ必須 = r.requiresRecipe;
        ギャンブル型 = r.isGambledRoulette;
        ペナルティ型 = r.isPenaltyRoulette;
        収録バインダー = wm.getBindersFor(レシピ名).map!(b => initBinderLink(b)).array;
        備考 = r.remarks;
    }
    return ri;
}

auto initItemInfo(Item item, WisdomModel wm) @trusted
{
    import std.algorithm;
    import std.conv;
    import std.range;

    ItemInfo it;
    with(it)
    {
        アイテム名 = item.name;
        英名 = item.ename;
        重さ = item.weight;
        NPC売却価格 = item.price;
        参考価格 = wm.costFor(item.name, (int[string]).init);
        info = item.info;
        特殊条件 = item.properties.map!(p => SpecialPropertyInfo(p.to!string, cast(string)p)).array;
        転送可 = item.transferable;
        スタック可 = item.stackable;
        ペットアイテム = item.petFoodInfo.byKeyValue.map!(kv => PetFoodInfo(cast(string)kv.key, kv.value)).front;
        if (auto rs = item.name in wm.wisdom.rrecipeList)
        {
            レシピ = (*rs)[].map!(r => initRecipeLink(r)).array;
        }
        else
        {
            レシピ = [];
        }
        備考 = item.remarks;
        アイテム種別 = cast(string)item.type;
        auto ex = wm.getExtraInfo(アイテム名);
        if (ex.extra == ExtraInfo.init)
        {
            return it;
        }

        final switch(item.type) with(typeof(item.type))
        {
        case UNKNOWN, Others:
            break;
        case Food, Drink, Liquor: {
            import coop.core.item: FInfo = FoodInfo;
            飲食物情報 = initFoodInfo(*ex.extra.peek!FInfo, wm);
            break;
        }
        case Weapon: {
            import coop.core.item: WInfo = WeaponInfo;
            武器情報 = initWeaponInfo(*ex.extra.peek!WInfo, wm);
            break;
        }
        case Armor: {
            import coop.core.item: AInfo = ArmorInfo;
            防具情報 = initArmorInfo(*ex.extra.peek!AInfo, wm);
            break;
        }
        case Bullet: {
            import coop.core.item: BInfo = BulletInfo;
            弾情報 = initBulletInfo(*ex.extra.peek!BInfo, wm);
            break;
        }
        case Shield: {
            import coop.core.item: SInfo = ShieldInfo;
            盾情報 = initShieldInfo(*ex.extra.peek!SInfo, wm);
            break;
        }
        case Expendable:
            break;
        case Asset:
            break;
        }
    }
    return it;
}


auto initFoodInfo(FInfo info, WisdomModel wm)
{
    FoodInfo fi;
    fi.効果 = info.effect;
    if (auto eff = info.additionalEffect)
    {
        fi.付加効果 = initFoodBufferInfo(eff, wm);
    }
    return fi;
}

auto initFoodBufferInfo(string eff, WisdomModel wm)
{
    FoodBufferInfo fb;
    fb.バフ名 = eff;
    if (auto einfo = wm.getFoodEffect(eff))
    {
        import std.conv;
        fb.バフグループ = einfo.group.to!string;
        fb.効果 = einfo.effects;
        fb.その他効果 = einfo.otherEffects;
        fb.効果時間 = einfo.duration;
        fb.備考 = einfo.remarks;
    }
    return fb;
}

auto initShipLink(string ship) @safe pure nothrow
{
    return ShipLink(ship);
}

auto initWeaponInfo(WInfo info, WisdomModel wm)
{
    import std.algorithm;
    import std.conv;
    import std.range;
    import std.traits;

    WeaponInfo wi;
    with(wi)
    {
        攻撃力 = [EnumMembers!Grade]
                 .filter!(g => info.damage.keys.canFind(g))
                 .map!(g => DamageInfo(cast(string)g, info.damage[g]))
                 .array;
        攻撃間隔 = info.duration;
        有効レンジ = info.range;
        必要スキル = info.skills
                         .byKeyValue
                         .map!(kv => initSkillNumberLink(kv.key, kv.value))
                         .array;
        両手装備 = info.isDoubleHands;
        装備スロット = cast(string)info.slot;
        装備可能シップ = info.restriction
                             .map!(s => initShipLink(cast(string)s))
                             .array;
        素材 = cast(string)info.material;
        消耗タイプ = cast(string)info.type;
        耐久 = info.exhaustion;
        追加効果 = info.effects;
        付加効果 = info.additionalEffect; //
        効果アップ = info.specials; //
        魔法チャージ = info.canMagicCharged;
        属性チャージ = info.canElementCharged;
    }
    return wi;
}

auto initArmorInfo(AInfo info, WisdomModel wm)
{
    import std.algorithm;
    import std.conv;
    import std.range;
    import std.traits;

    ArmorInfo ai;
    with(ai)
    {
        アーマークラス = [EnumMembers!Grade]
                         .filter!(g => info.AC.keys.canFind(g))
                         .map!(g => DamageInfo(cast(string)g, info.AC[g]))
                         .array;
        必要スキル = info.skills
                         .byKeyValue
                         .map!(kv => initSkillNumberLink(kv.key, kv.value))
                         .array;
        装備スロット = cast(string)info.slot;
        装備可能シップ = info.restriction
                             .map!(s => initShipLink(cast(string)s))
                             .array;
        素材 = cast(string)info.material;
        消耗タイプ = cast(string)info.type;
        耐久 = info.exhaustion;
        追加効果 = info.effects;
        付加効果 = info.additionalEffect;
        効果アップ = info.specials;
        魔法チャージ = info.canMagicCharged;
        属性チャージ = info.canElementCharged;
    }
    return ai;
}

auto initBulletInfo(BInfo info, WisdomModel wm) pure nothrow
{
    import std.algorithm;
    import std.range;

    BulletInfo bi;
    with(bi)
    {
        ダメージ = info.damage;
        有効レンジ = info.range;
        角度補正角 = info.angle;
        使用可能シップ = info.restriction
                             .map!(s => initShipLink(cast(string)s))
                             .array;
        必要スキル = info.skills
                         .byKeyValue
                         .map!(kv => initSkillNumberLink(kv.key, kv.value))
                         .array;
        追加効果 = info.effects;
        付与効果 = info.additionalEffect; //
    }
    return bi;
}

auto initShieldInfo(SInfo info, WisdomModel wm)
{
    import std.algorithm;
    import std.conv;
    import std.range;
    import std.traits;

    ShieldInfo si;
    with(si)
    {
        アーマークラス = [EnumMembers!Grade]
                         .filter!(g => info.AC.keys.canFind(g))
                         .map!(g => DamageInfo(cast(string)g, info.AC[g]))
                         .array;
        必要スキル = info.skills
                         .byKeyValue
                         .map!(kv => initSkillNumberLink(kv.key, kv.value))
                         .array;
        回避 = info.avoidRatio;
        使用可能シップ = info.restriction
                             .map!(s => initShipLink(cast(string)s))
                             .array;
        素材 = cast(string)info.material;
        消耗タイプ = cast(string)info.type;
        耐久 = info.exhaustion;
        追加効果 = info.effects;
        付加効果 = info.additionalEffect;
        効果アップ = info.specials;
        魔法チャージ = info.canMagicCharged;
        属性チャージ = info.canElementCharged;
    }
    return si;
}
