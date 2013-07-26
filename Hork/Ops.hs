module Hork.Ops (
  zinterp0OP, zinterp1OP, zinterp2OP, zinterpVAR
) where

import qualified Data.Map as M
import Hork.Core
import Hork.String
import Hork.Objects

import Data.Char (chr)


zinterp0OP :: Word8 -> Hork ()
zinterp0OP opcode = do
  let num = opcode .&. 15
  case M.lookup num ops0OP of
    Nothing -> die $ "No such 0OP opcode: " ++ show num
    Just op -> op

zinterp1OP :: Word8 -> Word8 -> Hork ()
zinterp1OP opcode typ = do
  let num = opcode .&. 15
  arg <- getArg typ
  case M.lookup num ops1OP of
    Nothing -> die $ "No such 1OP opcode: " ++ show num
    Just op -> op arg

zinterp2OP :: Word8 -> Word8 -> Word8 -> Hork ()
zinterp2OP opcode typ1 typ2 = do
  let num = opcode .&. 31
  arg1 <- getArg typ1
  arg2 <- getArg typ2
  case M.lookup num ops2OP of
    Nothing -> die $ "No such 2OP opcode: " ++ show num
    Just op -> op arg1 arg2

zinterpVAR :: Word8 -> [Word8] -> Hork ()
zinterpVAR opcode types = do
  let num = opcode .&. 31
  args <- mapM getArg types
  case M.lookup num opsVAR of
    Nothing -> die $ "No such VAR opcode: " ++ show num
    Just op -> op args



-----------------------------------------------------------
-- common helpers
-----------------------------------------------------------

zreturn :: Word16 -> Hork ()
zreturn value = do
  rts <- head <$> use routines
  stack .= rts ^. oldStack
  pc .= rts ^. oldPC
  zstore value

zstore :: Word16 -> Hork ()
zstore value = do
  b <- pcGet
  setVar b value


zbranch :: Bool -> Hork ()
zbranch val = do
  b1 <- pcGet
  let doBranch = val == (b1 ^. bitAt 7)
      isShort  = b1 ^. bitAt 6
  delta <- case isShort of
    True  -> return (fromIntegral b1 .&. 63)
    False -> do
      b2 <- pcGet
      -- combine into 14-bit number
      let w = fromIntegral (b1 .&. 63) `shiftL` 8 + fromIntegral b2 :: Int16
      -- sign-extend from 14 bits to 16
      return $ if w ^. bitAt 13 then w .|. (3 `shiftL` 14) else fromIntegral w :: Int16
  case delta of
    0 -> zreturn 0
    1 -> zreturn 1
    _ -> pcBumpBy (delta-2)



notImplemented :: String -> Hork ()
notImplemented func = die $ "Unimplemented opcode: " ++ func

-----------------------------------------------------------
-- 0OP instructions
-----------------------------------------------------------

type Op0OP = Hork ()

ops0OP :: M.Map Word8 Op0OP
ops0OP = M.fromList [
    (0, op_0OP_rtrue),
    (1, op_0OP_rfalse),
    (2, op_0OP_print),
    (3, op_0OP_print_ret),
    (4, op_0OP_nop),
    (5, op_0OP_save),
    (6, op_0OP_restore),
    (7, op_0OP_restart),
    (8, op_0OP_ret_popped),
    (9, op_0OP_pop),
    (10, op_0OP_quit),
    (11, op_0OP_new_line),
    (12, op_0OP_show_status),
    (13, op_0OP_verify),
    (15, op_0OP_piracy)
    ]

op_0OP_rtrue :: Op0OP
op_0OP_rtrue = zreturn 1

op_0OP_rfalse :: Op0OP
op_0OP_rfalse = zreturn 0

op_0OP_print :: Op0OP
op_0OP_print = do
  (s, len) <- use pc >>= strLenZ
  liftIO . putStr $ map (chr . fromIntegral) s
  pcBumpBy (2 * fromIntegral len)

op_0OP_print_ret :: Op0OP
op_0OP_print_ret = do
  op_0OP_print_ret
  zreturn 1

op_0OP_nop :: Op0OP
op_0OP_nop = return ()


op_0OP_save :: Op0OP
op_0OP_save = notImplemented "save"

op_0OP_restore :: Op0OP
op_0OP_restore = notImplemented "restore"


op_0OP_restart :: Op0OP
op_0OP_restart = throwError Restart


op_0OP_ret_popped :: Op0OP
op_0OP_ret_popped = pop >>= zreturn


op_0OP_pop :: Op0OP
op_0OP_pop = pop >> return ()


op_0OP_quit :: Op0OP
op_0OP_quit = throwError Exit


op_0OP_new_line :: Op0OP
op_0OP_new_line = liftIO $ putStrLn ""


op_0OP_show_status :: Op0OP
op_0OP_show_status = notImplemented "show_status"


op_0OP_verify :: Op0OP
op_0OP_verify = zbranch True


op_0OP_piracy :: Op0OP
op_0OP_piracy = zbranch True


type Op1OP = Word16 -> Hork ()

ops1OP :: M.Map Word8 Op1OP
ops1OP = M.fromList [
  (0, op_1OP_jz),
  (1, op_1OP_get_sibling),
  (2, op_1OP_get_child),
  (3, op_1OP_get_parent),
  (4, op_1OP_get_prop_len),
  (5, op_1OP_inc),
  (6, op_1OP_dec),
  (7, op_1OP_print_addr),
  --(8, op_1OP_call_1s
  (9, op_1OP_remove_obj),
  (10, op_1OP_print_obj),
  (11, op_1OP_ret),
  (12, op_1OP_jump),
  (13, op_1OP_print_paddr),
  (14, op_1OP_load),
  (15, op_1OP_not)
  ]


op_1OP_jz :: Op1OP
op_1OP_jz arg = zbranch (arg == 0)

op_1OP_get_sibling :: Op1OP
op_1OP_get_sibling = objSibling >=> rb >=> return . fromIntegral >=> zstore

op_1OP_get_child :: Op1OP
op_1OP_get_child = objChild >=> rb >=> return . fromIntegral >=> zstore

op_1OP_get_parent :: Op1OP
op_1OP_get_parent = objParent >=> rb >=> return . fromIntegral >=> zstore

op_1OP_get_prop_len :: Op1OP
op_1OP_get_prop_len arg = objPropLenFromAddr (ra (BA arg)) >>= zstore


op_1OP_inc :: Op1OP
op_1OP_inc = incdec (+1)
op_1OP_dec :: Op1OP
op_1OP_dec = incdec (subtract 1)

incdec :: (Word16 -> Word16) -> Op1OP
incdec f var = do
  let var' = fromIntegral var
  val <- getVar var'
  setVar var' (f val)


op_1OP_print_addr :: Op1OP
op_1OP_print_addr = printZ . BA

op_1OP_print_paddr :: Op1OP
op_1OP_print_paddr = printZ . PA



op_1OP_remove_obj :: Op1OP
op_1OP_remove_obj = objRemove


op_1OP_print_obj :: Op1OP
op_1OP_print_obj = objPrintShortName


op_1OP_ret :: Op1OP
op_1OP_ret = zreturn

op_1OP_jump :: Op1OP
op_1OP_jump uArg = pcBumpBy (fromIntegral uArg)


op_1OP_load :: Op1OP
op_1OP_load arg = getVar (fromIntegral arg) >>= zstore


op_1OP_not :: Op1OP
op_1OP_not arg = zstore (complement arg)


type Op2OP = Word16 -> Word16 -> Hork ()

ops2OP :: M.Map Word8 Op2OP
ops2OP = M.empty

type OpVAR = [Word16] -> Hork ()

opsVAR :: M.Map Word8 OpVAR
opsVAR = M.empty

