{-# LANGUAGE GeneralizedNewtypeDeriving, NoMonomorphismRestriction, BangPatterns, TemplateHaskell, OverloadedStrings #-}
module Main where

import Hork.Mem
import Hork.Header

import Control.Monad
import Control.Monad.State.Strict
import Control.Monad.Writer.Strict
import Control.Monad.Error
import Control.Applicative

import Data.Bits
import Data.Word
import Data.Int
import Data.List

import Control.Lens
import Data.Bits.Lens
import Data.List.Lens


import System.IO
import System.Environment (getArgs)


-- A stack of these is maintained in the main state, it holds the information necessary to
-- return from a routine call.
data RoutineState = RoutineState {
  _locals    :: ![Word16],
  _oldPC     :: !RA,
  _oldStack  :: ![Word16]
}
makeLenses ''RoutineState

-- Main state monad
data HorkState = HorkState {
  _mem       :: !Mem,
  _stack     :: ![Word16],
  _pc        :: !RA,
  _routines  :: ![RoutineState],
  _storyFile :: !FilePath
}
makeLenses ''HorkState


data Quit = Restart | Exit | Die String

instance Error Quit where
  noMsg = Exit
  strMsg = Die


newtype Hork a = Hork (ErrorT Quit (StateT HorkState (WriterT [String] IO)) a)
  deriving (Functor, Monad, MonadState HorkState, MonadWriter [String], MonadIO, MonadError Quit)


runHork :: HorkState -> Hork a -> IO (Either Quit a)
runHork st (Hork f) = do
  let mError = runErrorT f
      mState = runStateT mError st
      mWriter = runWriterT mState
  fst . fst <$> mWriter


-- Helper functions
log :: String -> String -> Hork ()
log loc msg = tell $ [loc ++ ":\t" ++ msg]


-- Specialized memory handlers
rb :: Addr a => a -> Hork Word8
rb a = do
  m <- use mem
  liftIO $ rb_ m (ra a)

wb :: Addr a => a -> Word8 -> Hork ()
wb a v = do
  m <- use mem
  liftIO $ wb_ m (ra a) v

rw :: Addr a => a -> Hork Word16
rw a = do
  m <- use mem
  liftIO $ rw_ m (ra a)

ww :: Addr a => a -> Word16 -> Hork ()
ww a v = do
  m <- use mem
  liftIO $ ww_ m (ra a) v


-- other helpers
pcBumpBy :: Word16 -> Hork ()
pcBumpBy delta = pc += ra (BA delta)

pcBump :: Hork ()
pcBump = pcBumpBy 1


-- variables

-- use cases for variables:
-- * store instructions
-- * arguments (by value)
-- * "by name" tweaks like inc and dec
-- locals and the stack can be handled with lenses, globals can't.

getLocal :: Word8 -> Hork Word16
getLocal var = use $ singular $ routines . _head . locals . element (fromIntegral var)

setLocal :: Word8 -> Word16 -> Hork ()
setLocal var val = routines . _head . locals . element (fromIntegral var) .= val

push :: Word16 -> Hork ()
push val = stack %= (val:)

pop :: Hork Word16
pop = stack %%= (\(x:xs) -> (x, xs))


getGlobal :: Word8 -> Hork Word16
getGlobal var = do
  let var' = fromIntegral var - 16
  table <- ra . BA <$> rw hdrGLOBALS
  rw $ table + 2*var'

setGlobal :: Word8 -> Word16 -> Hork ()
setGlobal var val = do
  let var' = fromIntegral var - 16
  table <- ra . BA <$> rw hdrGLOBALS
  ww (table + 2*var') val


-- startup flow:
-- 1) main reads the command line arguments and calls launch (IO)
-- 2) launch sets up the interpreter state, and calls restart (Hork)
-- 3) restart calls loadFile, then forever zinterp

zinterp :: Hork ()
zinterp = undefined


loadFile :: Hork ()
loadFile = undefined


restart :: Hork ()
restart = undefined

launch :: FilePath -> IO ()
launch file = undefined


main = do
  [file] <- getArgs
  launch file

