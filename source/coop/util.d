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
module coop.util;

import std.exception;
import std.json;

auto toBool(JSONValue val)
{
    enforce(val.type == JSON_TYPE.TRUE ||
            val.type == JSON_TYPE.FALSE);
    return val.type == JSON_TYPE.TRUE;
}

alias EventHandler(T...) = void delegate(T);