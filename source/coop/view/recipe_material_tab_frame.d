/**
 * Copyright: Copyright (c) 2016 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop/blob/master/LICENSE, MIT License)
 */
module coop.view.recipe_material_tab_frame;

import coop.view.tab_frame_base;

class RecipeMaterialTabFrame: TabFrameBase
{
    import dlangui;
    import std.container;

    import coop.controller.recipe_material_tab_frame_controller;
    import coop.model.recipe_graph;
    import coop.util;
    import coop.view.main_frame;

    mixin TabFrame;

    this() { super(); }

    this(string id)
    {
        import coop.view.editors;
        import coop.view.recipe_tab_frame;

        super(id);
        defaultMessage = "アイテム名";
        auto layout = new HorizontalLayout;
        addChild(layout);
        layout.margins = 20;
        layout.padding = 10;

        layout.addChild(recipeMaterialLayout);
        layout.addChild(recipeDetailsLayout);
        layout.layoutHeight(FILL_PARENT);
        layout.layoutWidth(FILL_PARENT);
        leafMaterials = new RedBlackTree!dstring;

        hideResult;
        childById!CheckBox("migemo").checkChange = (Widget src, bool checked) {
            migemoOptionChanged();
            return true;
        };

        childById!ComboBox("characters").itemClick = (Widget src, int idx) {
            characterChanged();
            return true;
        };

        childById!EditLine("itemQuery").contentChange = (EditableContent content) {
            if (timerID > 0)
            {
                cancelTimer(timerID);
            }
            if (window)
            {
                timerID = setTimer(300);
            }
        };

        childById!EditLine("itemQuery").popupMenu = editorPopupMenu;
        childById!EditLine("itemQuery").focusChange = (Widget src, bool focused) {
            if (focused)
            {
                if (src.text == defaultMessage)
                {
                    src.text = "";
                    src.textColor = "black";
                }
            }
            else
            {
                if (src.text == "")
                {
                    src.text = defaultMessage;
                    src.textColor = "gray";
                }
            }
            return true;
        };
        childById("itemQuery").text = defaultMessage;
        childById("itemQuery").textColor = "gray";

        preference = RecipeGraph.preference;
    }

    override @property EditLine queryBox()
    {
        return childById!EditLine("itemQuery");
    }

    override bool onTimer(ulong id)
    {
        if (queryBox.text != defaultMessage)
        {
            queryChanged();
        }
        return false;
    }

    override @property ComboBox charactersBox()
    {
        return childById!ComboBox("characters");
    }

    auto hideItemDetail(int idx)
    {
        childById("item"~(idx+1).to!string).visibility = Visibility.Gone;
    }

    auto showItemDetail(int idx)
    {
        childById("item"~(idx+1).to!string).visibility = Visibility.Visible;
    }

    @property auto recipeDetail()
    {
        import coop.view.recipe_detail_frame;

        return cast(RecipeDetailFrame)childById!FrameLayout("recipeDetail").child(0);
    }

    @property auto recipeDetail(Widget recipe)
    {
        auto frame = childById("recipeDetail");
        frame.removeAllChildren;
        frame.addChild(recipe);
    }

    override @property bool useMigemo()
    {
        return childById!CheckBox("migemo").checked;
    }

    override @property void useMigemo(bool use)
    {
        childById!CheckBox("migemo").checked = use;
    }

    override @property void disableMigemoBox()
    {
        with(childById!CheckBox("migemo"))
        {
            checked = false;
            enabled = false;
        }
    }

    override @property void enableMigemoBox()
    {
        childById!CheckBox("migemo").enabled = true;
    }

    auto setItemDetail(Widget item, int idx)
    {
        auto frame = childById("detailFrame"~(idx+1).to!string);
        frame.removeAllChildren;
        frame.addChild(item);
    }

    auto showCandidates(dstring[] candidates)
    {
        import std.algorithm;
        import std.range;

        auto scr = new ScrollWidget;
        auto tbl = new TableLayout("candidates");
        tbl.colCount = 3;
        scr.contentWidget = tbl;
        scr.backgroundColor = "white";
        scr.maxHeight = 300;

        auto mats = chain(toBeMade.keys, candidates.filter!(c => !toBeMade.keys.canFind(c))).map!((c) {
                import coop.view.controls;
                import coop.view.editors;

                auto w = new CheckableEntryWidget(c.to!string, c);
                auto o = new EditIntLine("own");
                auto t = new TextWidget(null, "個"d);
                o.enabled = false;
                o.minWidth = 55;
                o.popupMenu = editorPopupMenu;
                if (auto num = c in toBeMade)
                {
                    w.checked = true;
                    o.text = (*num).to!dstring;
                    o.enabled = true;
                }
                else
                {
                    o.text = "0";
                }

                w.detailClicked = {
                    import coop.model.item;
                    import coop.view.item_detail_frame;

                    unhighlightDetailItems;
                    scope(exit) highlightDetailItems;

                    Item item;
                    if (auto i = c in controller.wisdom.itemList)
                    {
                        item = *i;
                    }
                    else
                    {
                        item.name = c;
                        item.petFoodInfo = [PetFoodType.UNKNOWN.to!PetFoodType: 0];
                    }
                    showItemDetail(0);
                    setItemDetail(ItemDetailFrame.create(item, 1, controller.wisdom, controller.cWisdom), 0);
                };
                w.checkStateChanged = (bool checked) {
                    if (checked)
                    {
                        assert(c !in toBeMade);
                        assert(!o.enabled);
                        if (o.text.empty || o.text == "0")
                        {
                            o.text = "1";
                        }
                        toBeMade[c] = o.text.to!int;
                        o.enabled = true;
                    }
                    else
                    {
                        assert(c in toBeMade);
                        assert(o.enabled);
                        toBeMade.remove(c);
                        o.enabled = false;
                        o.text = "0";
                    }
                    if (toBeMade.keys.empty)
                    {
                        hideResult;
                    }
                    else
                    {
                        import std.typecons;

                        auto targets = toBeMade.byKeyValue.filter!(kv => kv.value > 0).map!(kv => tuple(kv.key, kv.value)).assocArray;
                        initializeTables(toBeMade.keys);
                        if (!targets.keys.empty)
                        {
                            updateTables(targets);
                        }
                    }
                };

                o.contentChange = (EditableContent content) {
                    import std.typecons;

                    if (!w.checked || !o.enabled)
                    {
                        return;
                    }
                    assert(c in toBeMade || c !in toBeMade); // 両方ありうる！
                    toBeMade[c] = content.text.empty ? 0 : content.text.to!int;
                    auto targets = toBeMade.byKeyValue.filter!(kv => kv.value > 0).map!(kv => tuple(kv.key, kv.value)).assocArray;
                    if (!hasShownResult)
                    {
                        initializeTables(toBeMade.keys);
                    }
                    if (!targets.keys.empty)
                    {
                        updateTables(targets, ownedMaterials);
                    }
                };

                return [w, o, t];
            });
        mats.each!(ms => tbl.addChildren(ms));

        auto candidateFrame = new VerticalLayout;
        candidateFrame.addChild(new TextWidget(null, "作成候補"d));
        candidateFrame.addChild(scr);

        auto helperFrame = childById("helper");
        helperFrame.removeAllChildren;
        helperFrame.addChild(candidateFrame);
    }

    auto hideResult()
    {
        childById("result").visibility = Visibility.Gone;
    }

    auto showResult()
    {
        childById("result").visibility = Visibility.Visible;
    }

    auto hasShownResult()
    {
        return childById("result").visibility == Visibility.Visible;
    }

    auto ownedMaterials()
    {
        import std.algorithm;
        import std.array;

        import coop.view.layouts;

        if (!hasShownResult)
        {
            return null;
        }
        auto tbl = childById!TableLayout("materials");
        return tbl.rows.map!((r) {
                import std.string;

                auto mat = r[0].text.chomp(": ");
                if (r[1].text.empty)
                {
                    import std.typecons;

                    return tuple(mat, 0);
                }
                else
                {
                    import std.typecons;

                    return tuple(mat, r[1].text.to!int);
                }
            }).filter!(a => a[1] > 0).assocArray;
    }

    auto initRecipeTable(dstring[] recipes)
    {
        import std.algorithm;

        auto fr = childById("recipeBase");
        fr.removeAllChildren;

        fr.addChild(new TextWidget(null, "必要レシピ"d));
        auto scr = new ScrollWidget;
        auto tbl = new TableLayout("recipes");
        tbl.colCount = 2;

        recipes.map!((r) {
                import std.format;

                import coop.view.controls;

                auto w = new LinkWidget(r.to!string, r~": ");
                auto t = new TextWidget("times", format("%s 回"d, 0));
                auto detail = controller.wisdom.recipeFor(r);
                w.click = (Widget _) {
                    import coop.view.recipe_detail_frame;

                    unhighlightDetailRecipe;
                    scope(exit) highlightDetailRecipe;
                    recipeDetail = RecipeDetailFrame.create(detail, controller.wisdom, controller.characters);
                    return true;
                };
                return cast(Widget[])[w, t];
            }).each!(c => tbl.addChildren(c));

        scr.contentWidget = tbl;
        scr.backgroundColor = "white";
        fr.addChild(scr);
    }

    auto initLeftoverTable(dstring[] leftovers)
    {
        import std.algorithm;

        auto fr = childById("leftoverBase");
        fr.removeAllChildren;

        fr.addChild(new TextWidget(null, "余り物"d));
        auto scr = new ScrollWidget;
        auto tbl = new TableLayout("leftovers");
        tbl.colCount = 2;

        leftovers.map!((lo) {
                import std.format;

                import coop.view.controls;

                auto w = new LinkWidget(lo.to!string, lo~": ");
                auto n = new TextWidget("num", format("%s 個"d, 0));
                w.click = (Widget _) {
                    import coop.model.item;
                    import coop.view.item_detail_frame;

                    unhighlightDetailItems;
                    scope(exit) highlightDetailItems;

                    Item item;
                    if (auto i = lo in controller.wisdom.itemList)
                    {
                        item = *i;
                    }
                    else
                    {
                        item.name = lo;
                        item.petFoodInfo = [PetFoodType.UNKNOWN.to!PetFoodType: 0];
                    }
                    showItemDetail(0);
                    setItemDetail(ItemDetailFrame.create(item, 1, controller.wisdom, controller.cWisdom), 0);
                    return true;
                };
                return cast(Widget[])[w, n];
            }).each!(c => tbl.addChildren(c));
        tbl.addChild(new TextWidget("なし", "なし"d));

        scr.contentWidget = tbl;
        scr.backgroundColor = "white";
        fr.addChild(scr);
    }

    auto initMaterialTable(dstring[] materials)
    {
        import std.algorithm;

        auto fr = childById("materialBase");
        fr.removeAllChildren;

        auto matCap = new HorizontalLayout;
        matCap.addChild(new TextWidget(null, "必要素材 (所持数/必要数)"d));
        auto clearButton = new Button(null, "全部しまう"d);
        matCap.addChild(clearButton);
        fr.addChild(matCap);

        auto scr = new ScrollWidget;
        auto tbl = new TableLayout("materials");
        tbl.colCount = 3;

        materials.map!((lo) {
                import std.format;

                import coop.view.controls;
                import coop.view.editors;

                auto w = new CheckableEntryWidget(lo.to!string, lo~": ");
                auto o = new EditIntLine("own");
                auto t = new TextWidget("times", format("/%s 個"d, 0));
                o.minWidth = 55;
                o.popupMenu = editorPopupMenu;

                w.checkStateChanged = (bool checked) {
                    if (isLocked)
                    {
                        return;
                    }

                    isLocked = true;
                    scope(exit) isLocked = false;
                    if (checked)
                    {
                        import std.regex;

                        o.text = t.text.matchFirst(r"/(\d+) 個"d)[1];
                    }
                    else
                    {
                        o.text = "0";
                    }
                };
                w.detailClicked = {
                    import coop.model.item;
                    import coop.view.item_detail_frame;

                    unhighlightDetailItems;
                    scope(exit) highlightDetailItems;

                    Item item;
                    if (auto i = lo in controller.wisdom.itemList)
                    {
                        item = *i;
                    }
                    else
                    {
                        item.name = lo;
                        item.petFoodInfo = [PetFoodType.UNKNOWN.to!PetFoodType: 0];
                    }
                    showItemDetail(0);
                    setItemDetail(ItemDetailFrame.create(item, 1, controller.wisdom, controller.cWisdom), 0);
                };
                o.contentChange = (EditableContent content) {
                    import std.regex;

                    updateTables(toBeMade, ownedMaterials);
                    if (isLocked)
                    {
                        return;
                    }
                    isLocked = true;
                    scope(exit) isLocked = false;
                    if (content.text >= t.text.matchFirst(r"/(\d+) 個"d)[1])
                    {
                        w.checked = true;
                    }
                };
                return [w, o, t];
            }).each!(c => tbl.addChildren(c));

        scr.contentWidget = tbl;
        scr.backgroundColor = "white";
        fr.addChild(scr);
        clearButton.click = (Widget _) {
            import coop.view.layouts;

            tbl.rows.map!"a[1]".each!(w => w.text = "0");
            return true;
        };
    }

    auto updateRecipeTable(int[dstring] recipes)
    {
        import std.algorithm;
        import std.exception;

        import coop.view.layouts;

        unhighlightDetailRecipe;
        scope(exit) highlightDetailRecipe;
        auto tbl = enforce(childById!TableLayout("recipes"));

        foreach(rs; tbl.rows)
        {
            import std.string;

            auto r = rs[0].text.chomp(": ");
            if (auto n  = r in recipes)
            {
                rs.each!(w => w.visibility = Visibility.Visible);
                rs[1].text = format("%s 回"d, *n);
                auto detail = controller.wisdom.recipeFor(r);
                auto c = controller.characters[charactersBox.selectedItem];
                if (!c.hasSkillFor(detail) || (detail.requiresRecipe && !c.hasRecipe(r)))
                {
                    rs[0].textColor = "gray";
                }
                else if (detail.ingredients.keys.all!(ing => childById!TableLayout("materials").row(ing.to!string)[0].checked))
                {
                    rs[0].textColor = "red";
                }
                else
                {
                    rs[0].textColor = "black";
                }

                auto rNode = fullGraph.recipeNodes[r];
                if (!rNode.parents.empty)
                {
                    import std.array;

                    auto bros = rNode.parents[]
                                     .map!(p => fullGraph.materialNodes[p].children)
                                     .join
                                     .map!"a.name"
                                     .array
                                     .sort()
                                     .uniq
                                     .array;
                    if (bros.length > 1)
                    {
                        import std.typecons;

                        import coop.view.controls;

                        auto menu = bros.filter!(b => b != r)
                                        .map!(b => tuple(format("%s を使う"d, b), () {
                                                    preference[rNode.parents[].front] = b;
                                                    reload;
                                                }))
                                        .array;
                        auto lw = (cast(LinkWidget)rs[0]);
                        lw.popupMenu = menu;
                        lw.textFlags = TextFlag.Underline;
                    }
                }
            }
            else
            {
                rs.each!(w => w.visibility = Visibility.Gone);
            }
        }
    }

    auto updateLeftoverTable(int[dstring] leftovers)
    {
        import std.algorithm;
        import std.exception;
        import std.range;

        import coop.view.layouts;

        unhighlightDetailItems;
        scope(exit) highlightDetailItems;
        auto tbl = enforce(childById!TableLayout("leftovers"));
        foreach(rs; tbl.rows)
        {
            import std.string;

            if (auto n = rs[0].text.chomp(": ") in leftovers)
            {
                rs.each!(w => w.visibility = Visibility.Visible);
                rs[1].text = format("%s 個"d, *n);
            }
            else
            {
                rs.each!(w => w.visibility = Visibility.Gone);
            }
        }
        if (leftovers.keys.empty)
        {
            tbl.childById("なし").visibility = Visibility.Visible;
        }
    }

    auto updateMaterialTable(MatTuple[dstring] materials)
    {
        import std.algorithm;
        import std.exception;

        import coop.view.layouts;

        unhighlightDetailItems;
        scope(exit) highlightDetailItems;
        auto tbl = enforce(childById!TableLayout("materials"));
        foreach(rs; tbl.rows)
        {
            import std.string;

            isLocked = true;
            scope(exit) isLocked = false;

            auto m = rs[0].text.chomp(": ");
            if (auto n = m in materials)
            {
                rs.each!(w => w.visibility = Visibility.Visible);
                rs[2].text = format("/%s 個"d, (*n).num);
                rs[0].textColor = (*n).isIntermediate ? "blue" : "black";
                if (!rs[1].text.empty && rs[1].text.to!int >= (*n).num)
                {
                    rs[0].checked = true;
                }
                else
                {
                    rs[0].checked = false;
                }

                auto mNode = fullGraph.materialNodes[m];
                if (!mNode.isLeaf)
                {
                    import std.typecons;

                    import coop.view.controls;

                    Tuple!(dstring, void delegate()) menuItem;
                    if (mNode.name in leafMaterials)
                    {
                        menuItem = tuple("材料から用意する"d, () {
                                leafMaterials.removeKey(mNode.name);
                                reload;
                            });
                    }
                    else
                    {
                        menuItem = tuple("直接用意する"d, () {
                                leafMaterials.insert(mNode.name);
                                reload;
                            });
                    }
                    auto cew = (cast(CheckableEntryWidget)rs[0]);
                    cew.popupMenu = [menuItem];
                    cew.textFlags = TextFlag.Underline;
                }
            }
            else
            {
                rs.each!(w => w.visibility = Visibility.Gone);
            }
        }
    }

    auto initializeTables(dstring[] items)
    {
        fullGraph = new RecipeGraph(items, controller.wisdom, null);

        auto elems = fullGraph.elements;
        initRecipeTable(elems.recipes);
        initLeftoverTable(elems.materials);
        initMaterialTable(elems.materials);
    }

    auto updateTables(int[dstring] targets, int[dstring] owned = null)
    {
        import std.algorithm;
        import std.array;

        if (subGraph is null || !fullGraph.targets.equal(subGraph.targets))
        {
            subGraph = new RecipeGraph(targets.keys, controller.wisdom, preference);
        }
        auto elems = subGraph.elements(targets, owned, controller.wisdom, leafMaterials);
        auto mats = setDifference!"a.key < b.key"(elems.materials.byKeyValue.array.schwartzSort!"a.key",
                                                  targets.byKeyValue.array.schwartzSort!"a.key").map!"tuple(a.key, a.value)".assocArray;
        updateMaterialTable(mats); // 最初にすること！
        updateRecipeTable(elems.recipes);
        updateLeftoverTable(elems.leftovers);
        showResult;
    }

    void reload()
    in{
        assert(hasShownResult);
    } body {
        import std.algorithm;
        import std.array;
        import std.typecons;

        subGraph = null;
        updateTables(toBeMade.byKeyValue.filter!(kv => kv.value > 0).map!(kv => tuple(kv.key, kv.value)).assocArray, ownedMaterials);
     }

    auto highlightDetailRecipe()
    {
        // if (recipeDetail)
        // {
        //     if (auto tbl = childById!TableLayout("recipes"))
        //     {
        //         if (auto r = tbl.row(recipeDetail.name.to!string))
        //         {
        //             (cast(LinkWidget)r[0]).highlight;
        //         }
        //     }
        // }
    }

    auto unhighlightDetailRecipe()
    {
        // if (auto tbl = childById!TableLayout("recipes"))
        // {
        //     tbl.rows.map!(r => cast(LinkWidget)r[0]).each!(r => r.unhighlight);
        // }
    }

    auto highlightDetailItems()
    {
        // if (auto fr = childById!ItemDetailFrame("detail1"))
        // {
        //     auto shownItem = fr.item.name.to!string;
        //     if (auto loTable = childById!TableLayout("leftovers"))
        //     {
        //         if (auto r = loTable.row(shownItem))
        //         {
        //             (cast(LinkWidget)r[0]).highlight;
        //         }
        //     }

        //     if (auto matTable = childById!TableLayout("materials"))
        //     {
        //         if (auto r = matTable.row(shownItem))
        //         {
        //             (cast(CheckableEntryWidget)r[0]).highlight;
        //         }
        //     }
        // }
    }

    auto unhighlightDetailItems()
    {
        // if (auto loTable = childById!TableLayout("leftovers"))
        // {
        //     loTable.rows.filter!(r => r[0].id != "なし").map!(r => cast(LinkWidget)r[0]).each!(r => r.unhighlight);
        // }
        // if (auto matTable = childById!TableLayout("materials"))
        // {
        //     matTable.rows.map!(r => cast(CheckableEntryWidget)r[0]).each!(r => r.unhighlight);
        // }
    }

    int[dstring] toBeMade;
    bool isLocked;
    EventHandler!() migemoOptionChanged;
    EventHandler!() queryChanged;
    EventHandler!() characterChanged;
    RecipeGraph fullGraph;
    RecipeGraph subGraph;
    dstring[dstring] preference;
    RedBlackTree!dstring leafMaterials;
    ulong timerID;
}

auto recipeMaterialLayout()
{
    import dlangui;

    auto layout = parseML(q{
            VerticalLayout {
                HorizontalLayout {
                    TextWidget { text: "キャラクター" }
                    ComboBox {
                        id: characters
                    }
                }

                EditLine {
                    id: itemQuery
                    minWidth: 300
                }
                CheckBox { id: migemo; text: "Migemo 検索" }

                FrameLayout {
                    id: helper
                    padding: 1
                }

                VerticalLayout {
                    id: result
                    TextWidget { text: "必要レシピ情報" }
                    HorizontalLayout {
                        padding: 1
                        VerticalLayout {
                            VerticalLayout {
                                id: recipeBase
                            }
                            VerticalLayout {
                                id: leftoverBase
                            }
                        }
                        VerticalLayout {
                            id: materialBase
                        }
                    }
                }
            }
        });
    return layout;
}
