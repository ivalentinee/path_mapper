defmodule PathMapperWeb.Router do
  use PathMapperWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PathMapperWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PathMapperWeb.Plugs.Locale
  end

  pipeline :api_public do
    plug :accepts, ["json"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug PathMapperWeb.Plugs.TokenAuth
    plug PathMapperWeb.Plugs.SchemaGate
  end

  scope "/", PathMapperWeb do
    pipe_through :browser

    live "/", PlayerLive
    live "/master", MasterLive
  end

  scope "/api", PathMapperWeb do
    pipe_through :api_public

    get "/openapi.json", ApiDocumentController, :show
  end

  scope "/api", PathMapperWeb do
    pipe_through :api

    post "/scenes/map", MapUploadController, :upload
    post "/assets", AssetController, :create
    post "/reset", SessionController, :reset
    post "/entities", EntityController, :create
    get "/entities", EntityController, :index
    delete "/entities/:id", EntityController, :delete
    get "/state", StateController, :show
    post "/state", StateController, :update
  end
end
