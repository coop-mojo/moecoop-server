/**
 * Copyright: Copyright 2017 Mojo
 * Authors: Mojo
 * License: $(LINK2 https://github.com/coop-mojo/moecoop/blob/master/LICENSE, MIT License)
 */
module coop.mui.model.wisdom_adapter;

public import coop.server.model;
public import coop.server.model.internal: WebModel;

class WisdomAdapter
{
    this(string endpoint)
    {
        this.api = new typeof(api)(endpoint);
        this.endpoint = endpoint;
    }

    GetRecipesResult getBinderRecipes(string binder, string query, bool migemo, bool rev, string key)
    {
        import std.array;
        import vibe.http.common;
        binder = binder.replace("/", "_");
        try {
            return api.getBinderRecipes(binder, query, migemo, rev, key);
        } catch(HTTPStatusException e) {
            throw e;
        } catch(Exception e) {
            if (e.msg == "Reading from TLS stream was unsuccessful with ret 0")
            {
                return api.getBinderRecipes(binder, query, migemo, rev, key);
            }
            else
            {
                import std.format;
                throw new Exception(format("%s in api.getBinderRecipes(%s, %s, %s, %s, %s)",
                                           e.msg, binder, query, migemo, rev, key));
            }
        }
    }

    RecipeInfo getRecipe(string _recipe)
    {
        import std.array;
        import vibe.http.common;
        _recipe = _recipe.replace("/", "_");
        try {
            return api.getRecipe(_recipe);
        } catch(HTTPStatusException e) {
            throw e;
        } catch(Exception e) {
            if (e.msg == "Reading from TLS stream was unsuccessful with ret 0")
            {
                return api.getRecipe(_recipe);
            }
            else
            {
                import std.format;
                throw new Exception(format("%s in api.getRecipe(%s)", e.msg, _recipe));
            }
        }
    }

    @property auto opDispatch(string op)()
    {
        import vibe.http.common;
        enum callStr = "api."~op;
        try {
            return mixin(callStr);
        } catch(HTTPStatusException e) {
            throw e;
        } catch(Exception e) {
            if (e.msg == "Reading from TLS stream was unsuccessful with ret 0")
            {
                return mixin(callStr);
            }
            else
            {
                import std.format;
                throw new Exception(format("%s in api.%s", e.msg, op));
            }
        }
    }

    auto opDispatch(string op, Args...)(Args args)
    {
        import vibe.http.common;
        enum callStr = "api."~op~"(args)";
        try {
            return mixin(callStr);
        } catch(HTTPStatusException e) {
            throw e;
        } catch(Exception e) {
            if (e.msg == "Reading from TLS stream was unsuccessful with ret 0")
            {
                return mixin(callStr);
            }
            else
            {
                import std.format;
                throw new Exception(format("%s in api.%s(%s)", e.msg, op, args));
            }
        }

    }

private:
    import vibe.web.rest;
    RestInterfaceClient!ModelAPI api;

    string endpoint;
}
