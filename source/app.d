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
import dlangui;

import std.path;

import coop.config;
import coop.wisdom;
import coop.widget;

mixin APP_ENTRY_POINT;

immutable SystemResourceBase = "resource";
immutable UserResourceBase = "userdata";
immutable AppName = "生協の知恵袋"d;

extern(C) int UIAppMain(string[] args)
{
    auto wisdom = new Wisdom(SystemResourceBase, UserResourceBase);
    scope(exit) wisdom.destroy;
    auto config = new Config(buildPath(UserResourceBase, "config.json"));
    scope(exit) config.destroy;

    Platform.instance.uiLanguage = "ja";
    Platform.instance.uiTheme = "theme_default";
    auto window = Platform.instance.createWindow(AppName, null, WindowFlag.Resizable,
                                                 config.windowWidth,
                                                 config.windowHeight);
    auto layout = createBinderListLayout(window, wisdom, config);
    window.mainWidget = layout;
    window.show;
    window.onClose = {
        version(Windows) {
            config.windowWidth = pixelsToPoints(window.width);
            config.windowHeight = pixelsToPoints(window.height);
        }
        else {
            config.windowWidth = window.width;
            config.windowHeight = window.height;
        }
    };
    return Platform.instance.enterMessageLoop();
}
