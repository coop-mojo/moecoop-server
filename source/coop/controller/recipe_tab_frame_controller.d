/**
   MoeCoop
   Copyright (C) 2016  Mojo

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
module coop.controller.recipe_tab_frame_controller;

import dlangui;

import std.algorithm;
import std.container.util;
import std.range;
import std.regex;
import std.typecons;

import coop.model.recipe;
import coop.model.wisdom;
import coop.view.recipe_tab_frame;
import coop.view.recipe_detail_frame;
import coop.controller.main_frame_controller;

enum SortOrder {
    BySkill       = "スキル値順"d,
    ByName        = "名前順",
    ByBinderOrder = "バインダー順",
}

abstract class RecipeTabFrameController
{
    mixin TabController;

    this(RecipeTabFrame frame)
    {
        frame_ = frame;
        frame_.queryFocused = {
            if (frame_.queryText == defaultTxtMsg)
            {
                frame_.queryText = ""d;
            }
        };

        frame_.queryChanged =
            frame_.metaSearchOptionChanged =
            frame_.migemoOptionChanged =
            frame_.categoryChanged =
            frame_.characterChanged =
            frame_.nColumnChanged =
            frame_.sortKeyChanged = {
            showBinderRecipes;
        };

        Recipe dummy;
        dummy.techniques = make!(typeof(dummy.techniques))(cast(dstring)[]);
        frame_.recipeDetail = RecipeDetailFrame.create(dummy, wisdom, characters);

        frame_.characters = characters.keys.sort().array;

        frame_.hideItemDetail(0);
        frame_.hideItemDetail(1);

        if (migemo)
        {
            frame_.enableMigemoBox;
        }
        else
        {
            frame_.disableMigemoBox;
        }
    }

    auto showBinderRecipes()
    {
        import std.string;

        if (frame_.queryText == defaultTxtMsg)
        {
            frame_.queryText = ""d;
        }

        auto query = frame_.queryText.removechars(r"/[ 　]/");
        if (frame_.useMetaSearch && query.empty)
            return;

        dstring[][dstring] recipes;
        if (frame_.useMetaSearch)
        {
            recipes = recipeChunks(wisdom);
        }
        else
        {
            auto c = frame_.selectedCategory;
            recipes = recipeChunksFor(wisdom, c);
        }

        if (!query.empty)
        {
            bool delegate(dstring) matchFun =
                s => !find(s.removechars(r"/[ 　]/"), boyerMooreFinder(query)).empty;
            if (frame_.useMigemo)
            {
                try{
                    auto q = migemo.query(query).regex;
                    matchFun = s => !s.removechars(r"/[ 　]/").matchFirst(q).empty;
                } catch(RegexException e) {
                    // use default matchFun
                }
            }
            recipes = recipes
                      .byKeyValue
                      .map!(kv =>
                            tuple(kv.key,
                                  kv.value.filter!matchFun.array))
                      .assocArray;
        }

        auto chunks = recipes.byKeyValue.map!((kv) {
                auto category = kv.key;
                auto rs = kv.value;

                alias Entry = Tuple!(dstring, "key", typeof(rs.array), "value");

                if (rs.empty)
                    return [Entry(category, rs.array)];
                final switch(frame_.sortKey) with(SortOrder)
                {
                case BySkill:
                    auto levels(dstring s) {
                        auto arr = wisdom.recipeFor(s).requiredSkills.byKeyValue.map!(a => tuple(a.key, a.value)).array;
                        arr.multiSort!("a[0] < b[0]", "a[1] < b[1]");
                        return arr;
                    }
                    auto lvToStr(Tuple!(dstring, real)[] tpls)
                    {
                        return tpls.map!(t => format("%s (%.1f)"d, t.tupleof)).join(", ");
                    }
                    auto arr = rs.map!(a => tuple(a, levels(a))).array;
                    arr.multiSort!("a[1] < b[1]", "a[0] < b[0]");
                    return arr.chunkBy!"a[1]"
                        .map!(a => Entry(lvToStr(a[0]), a[1].map!"a[0]".array))
                        .array;
                case ByName, ByBinderOrder:
                    return [Entry(category, rs.sort().array)];
                }
            }).joiner;

        Widget[] tableElems = chunks.map!((kv) {
                auto category = kv.key;
                auto recipes = kv.value;
                if (recipes.empty)
                    return Widget[].init;

                Widget[] header = [];
                if (frame_.useMetaSearch || useHeader(frame_))
                {
                    Widget hd = new TextWidget("", category);
                    hd.backgroundColor = 0xCCCCCC;
                    header = [hd];
                }
                return header~toRecipeWidgets(recipes, category);
            }).join;
        frame_.showRecipeList(tableElems, frame_.numberOfColumns);
    }

    @property auto categories(dstring[] cats)
    {
        frame_.categories = cats;
    }
protected:
    abstract dstring[][dstring] recipeChunks(Wisdom wisdom);
    abstract dstring[][dstring] recipeChunksFor(Wisdom wisdom, dstring cat);
    abstract bool useHeader(RecipeTabFrame frame);
    abstract Widget[] toRecipeWidgets(dstring[], dstring);

private:
    enum defaultTxtMsg = "見たいレシピ";
}