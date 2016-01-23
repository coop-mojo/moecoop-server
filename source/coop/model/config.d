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
module coop.model.config;

import std.conv;
import std.exception;
import std.file;
import std.json;

class Config {
    this(string file)
    {
        if (file.exists)
        {
            auto json = file.readText.parseJSON;
            enforce(json.type == JSON_TYPE.OBJECT);
            windowWidth = json["initWindowWidth"].integer.to!uint;
            windowHeight = json["initWindowHeight"].integer.to!uint;
            font = json["font"].str;
            migemoDLL = json["migemoDLL"].str.to!dstring;
            migemoDict = json["migemoDict"].str.to!dstring;
        }
        else
        {
            // デフォルト値を設定
            windowWidth = 400;
            windowHeight = 300;
            version(Windows) {
                migemoDLL = `C:\Program Files (x86)\cmigemo-defalut-win32\migemo.dll`d;
                migemoDict = `C:\Program Files (x86)\cmigemo-default-win32\dict\utf-8`d;
            }
            version(linux) {
                migemoDLL = "/usr/lib/libmigemo.so"d;
                migemoDict = "/usr/share/migemo/utf-8"d;
            }
            else version(OSX)
            {
                migemoDLL = "/usr/local/opt/cmigemo/lib/libmigemo.dylib"d;
                migemoDict = "/usr/local/opt/cmigemo/share/migemo/utf-8"d;
            }
        }
        configFile = file;
    }

    ~this()
    {
        import std.stdio;
        import std.path;
        mkdirRecurse(configFile.dirName);
        auto f = File(configFile, "w");
        f.write(toJSON);
    }

    auto toJSON() {
        auto json = JSONValue([ "initWindowWidth": JSONValue(windowWidth),
                                "initWindowHeight": JSONValue(windowHeight),
                                "font": JSONValue(font),
                                "migemoDLL": JSONValue(migemoDLL.to!string),
                                "migemoDict": JSONValue(migemoDict.to!string),
                                  ]);
        return json.toPrettyString;
    }

    uint windowWidth, windowHeight;
    immutable string font;
    dstring migemoDLL;
    dstring migemoDict;
private:
    string configFile;
}