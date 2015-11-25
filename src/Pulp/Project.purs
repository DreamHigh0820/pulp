
module Pulp.Project
  ( Project()
  , getProject
  ) where

import Prelude
import Data.Maybe (Maybe(..), maybe)
import Data.Either (Either(..))
import Control.Monad.Error.Class (throwError)
import Control.Monad.Eff.Exception (error)
import Control.Monad.Eff.Class (liftEff)
import Data.Foreign (Foreign(), parseJSON)

import Node.FS.Aff (exists, readTextFile, mkdir)
import Node.Encoding (Encoding(UTF8))
import qualified Node.Path as P

import Pulp.System.FFI
import qualified Pulp.System.Process as Process
import Pulp.Args (Options(), getOption)

type Project =
  { bowerFile :: Foreign
  , path :: String
  , cache :: String
  }

-- | Attempt to find a file in the given directory or any parent of it.
findIn :: forall e. String -> String -> AffN e (Maybe String)
findIn path file = do
  let fullPath = P.concat [path, file]
  doesExist <- exists fullPath

  if doesExist
    then return (Just fullPath)
    else if path == "/"
            then return Nothing
            else findIn (P.dirname path) file

-- | Read a project's bower file at the given path and construct a Project
-- | value.
readConfig :: forall e. String -> AffN e Project
readConfig configFilePath = do
  json <- readTextFile UTF8 configFilePath
  case parseJSON json of
    Left err -> throwError (error (show err))
    Right pro -> do
      let path = P.dirname configFilePath
      let cachePath = P.resolve [path] ".pulp-cache"
      liftEff $ Process.chdir path
      mkdir cachePath
      return { bowerFile: pro, cache: cachePath, path: path }

-- | Use the provided bower file, or if it is Nothing, try to find a bower file
-- | path in this or any parent directory.
getBowerFile :: forall e. Maybe String -> AffN e String
getBowerFile = maybe search pure
  where
  search = do
    cwd <- liftEff Process.cwd
    mbowerFile <- findIn cwd "bower.json"
    case mbowerFile of
      Just bowerFile -> pure bowerFile
      Nothing -> throwError <<< error $
        "No bower.json found in current or parent directories. Are you in a PureScript project?"

getProject :: forall e. Options -> AffN e Project
getProject args =
  getOption "bowerFile" args >>= getBowerFile >>= readConfig
