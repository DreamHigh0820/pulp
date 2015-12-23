
module Pulp.Exec
  ( exec
  , execQuiet
  , psc
  , pscBundle
  ) where

import Prelude
import Data.Either (Either(..), either)
import Data.Function
import Data.String (stripSuffix)
import Data.StrMap (StrMap())
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Array as Array
import Control.Monad.Error.Class (MonadError, throwError)
import Control.Monad.Eff.Exception (Error(), error)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Aff
import Control.Monad.Aff.AVar (takeVar, putVar, makeVar)
import Node.Process as Process
import Node.Platform (Platform(Win32))
import Node.ChildProcess as CP
import Unsafe.Coerce (unsafeCoerce)

import Pulp.System.Stream
import Pulp.System.FFI

psc :: Array String -> Array String -> Array String -> Maybe (StrMap String) -> AffN String
psc deps ffi args env =
  let allArgs = args <> deps <> (Array.concatMap (\path -> ["--ffi", path]) ffi)
  in  execQuiet "psc" allArgs env

pscBundle :: Array String -> Array String -> Maybe (StrMap String) -> AffN String
pscBundle files args env =
  execQuiet "psc-bundle" (files <> args) env

inheritAllButStdout :: Array (Maybe CP.StdIOBehaviour)
inheritAllButStdout = updateAt 1 (Just CP.Pipe) CP.inherit
  where
  updateAt n f arr = fromMaybe arr (Array.updateAt n f arr)

-- | Start a child process asynchronously, with the given command line
-- | arguments and environment, and wait for it to exit.
-- | On a non-zero exit code, throw an error.
--
-- | If the executable was not found and we are on Windows, retry with ".cmd"
-- | appended.
-- |
-- | Stdout, stdin, and stderr of the child process are shared with the pulp
-- | process (that is, data on stdin from pulp is relayed to the child process,
-- | and any stdout and stderr from the child process are relayed back out by
-- | pulp, which usually means they will immediately appear in the terminal).
exec :: String -> Array String -> Maybe (StrMap String) -> AffN Unit
exec cmd args env = do
  child <- liftEff $ CP.spawn cmd args (def { env = env
                                            , stdio = CP.inherit })
  wait child >>= either (handleErrors cmd retry) onExit

  where
  def = CP.defaultSpawnOptions

  onExit exit =
    case exit of
      CP.Normally 0 ->
        pure unit
      _ ->
        throwError $ error $
            "Subcommand terminated " <> showExit exit

  retry newCmd = exec newCmd args env

-- | Same as exec, except instead of relaying stdout immediately, it is
-- | captured and returned as a String.
execQuiet :: String -> Array String -> Maybe (StrMap String) -> AffN String
execQuiet cmd args env = do
  child <- liftEff $ CP.spawn cmd args (def { env = env
                                            , stdio = inheritAllButStdout })
  outVar <- makeVar
  forkAff (concatStream (CP.stdout child) >>= putVar outVar)
  wait child >>= either (handleErrors cmd retry) (onExit outVar)

  where
  def = CP.defaultSpawnOptions

  onExit outVar exit =
    takeVar outVar >>= \childOut ->
      case exit of
        CP.Normally 0 ->
          pure childOut
        _ -> do
          write Process.stderr childOut
          throwError $ error $ "Subcommand terminated " <> showExit exit

  retry newCmd = execQuiet newCmd args env

-- | A slightly weird combination of `onError` and `onExit` into one.
wait :: CP.ChildProcess -> AffN (Either CP.ChildProcessError CP.ChildProcessExit)
wait child = makeAff \_ win -> do
  CP.onExit child (win <<< Right)
  CP.onError child (win <<< Left)

showExit :: CP.ChildProcessExit -> String
showExit (CP.Normally x) = "with exit code " <> show x
showExit (CP.BySignal sig) = "as a result of receiving " <> show sig

handleErrors :: forall a. String -> (String -> AffN a) -> CP.ChildProcessError -> AffN a
handleErrors cmd retry err
  | err.code == "ENOENT" = do
     -- On windows, if the executable wasn't found, try adding .cmd
     if Process.platform == Win32
       then case stripSuffix ".cmd" cmd of
              Nothing      -> retry (cmd <> ".cmd")
              Just bareCmd -> throwError $ error $
                 "`" <> bareCmd <> "` executable not found. (nor `" <> cmd <> "`)"
       else
         throwError $ error $
           "`" <> cmd <> "` executable not found."
  | otherwise =
     throwError (toErr err)
     where
     toErr :: CP.ChildProcessError -> Error
     toErr = unsafeCoerce

concatStream :: ReadableStream -> AffN String
concatStream stream = runNode $ runFn2 concatStream' stream

foreign import concatStream' :: Fn2 ReadableStream (Callback String) Unit
