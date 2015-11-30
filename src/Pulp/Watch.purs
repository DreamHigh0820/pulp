
module Pulp.Watch
  ( watch
  , watchAff
  , action
  ) where

import Prelude
import Data.Function
import Data.Maybe (fromMaybe)
import Data.Array as Array
import Data.Set as Set
import Data.Map as Map
import Data.Foldable (any, notElem)
import Control.Monad (when)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Aff (launchAff)
import Control.Monad.Aff.AVar as AVar
import Control.Monad.Eff.Console (log)

import Pulp.Args
import Pulp.Args.Get
import Pulp.Files
import Pulp.System.FFI
import Pulp.System.Log as Log
import Pulp.System.Process as Process
import Pulp.System.ChildProcess (ChildProcess(), fork, treeKill)

foreign import watch :: forall e.
  Array String
  -> (String -> EffN e Unit)
  -> EffN e Unit

watchAff :: forall e. Array String -> (String -> AffN e Unit) -> AffN e Unit
watchAff dirs callback =
  liftEff (watch dirs (\path -> launchAff (callback path)))

foreign import minimatch :: String -> String -> Boolean

action :: Action
action = Action \args -> do
  let opts = Map.union args.globalOpts args.commandOpts

  let argv' = Array.filter (`notElem` ["-w", "--watch"]) Process.argv
  childV <- AVar.makeVar
  liftEff (fork argv') >>= AVar.putVar childV

  srcPath        <- getOption' "srcPath" opts
  testPath       <- getOption' "testPath" opts
  dependencyPath <- getOption' "dependencyPath" opts
  includePaths   <- fromMaybe [] <$> getOption "includePaths" opts
  let directories = [ srcPath, testPath, dependencyPath ] ++ includePaths

  globs <- Set.union <$> defaultGlobs opts <*> testGlobs opts
  let fileGlobs = sources globs ++ ffis globs

  watchAff directories $ \path -> do
    Log.log $ "changed: " ++ path
    when (any (minimatch path) fileGlobs) do
      child <- AVar.takeVar childV
      liftEff $ treeKill child.pid "SIGTERM"
      Log.log "Source tree changed; restarting:"
      liftEff (fork argv') >>= AVar.putVar childV
