module TreeSitter.Importing where

import Control.Exception as Exc
import Data.ByteString

import           Data.ByteString.Unsafe (unsafeUseAsCStringLen)
import           Foreign
import TreeSitter.Node as TS
import TreeSitter.Parser as TS
import TreeSitter.Tree as TS

data Expression
      = NumberExpression Number | IdentifierExpression Identifier
      deriving (Eq, Ord, Show)

data Number = Number
      deriving (Eq, Ord, Show)

data Identifier = Identifier
      deriving (Eq, Ord, Show)


importByteString :: (Importing t) => Ptr TS.Parser -> ByteString -> IO (Maybe t)
importByteString parser bytestring =
  unsafeUseAsCStringLen bytestring $ \ (source, len) -> alloca (\ rootPtr -> do
      let acquire =
            ts_parser_parse_string parser nullPtr source len

      let release t
            | t == nullPtr = pure ()
            | otherwise = ts_tree_delete t

      let go treePtr =
            if treePtr == nullPtr
              then pure Nothing
              else do
                ts_tree_root_node_p treePtr rootPtr
                node <- peek rootPtr
                Just <$> import' node
      Exc.bracket acquire release go)

instance (Importing a, Importing b) => Importing (a,b) where
  import' node = do
    [a,b] <- allocaArray 2 $ \ childNodesPtr -> do
      _ <- with (nodeTSNode node) (flip ts_node_copy_child_nodes childNodesPtr)
      peekArray 2 childNodesPtr
    a' <- import' a
    b' <- import' b
    pure (a',b')

class Importing type' where

  import' :: Node -> IO type'

-----------------
-- | Notes
-- ToAST takes Node -> IO (value of datatype)
-- splice will generate instances of this class
-- CodeGen will import TreeSitter.Importing (why?)
