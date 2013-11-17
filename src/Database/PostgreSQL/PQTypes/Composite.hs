{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE DeriveDataTypeable, DeriveFunctor, FlexibleContexts
  , ScopedTypeVariables, TypeFamilies #-}
module Database.PostgreSQL.PQTypes.Composite (
    Composite(..)
  , unComposite
  , CompositeRow
  , CompositeFromSQL(..)
  , CompositeToSQL(..)
  ) where

import Control.Applicative
import Data.Typeable
import Foreign.Ptr
import qualified Control.Exception as E

import Database.PostgreSQL.PQTypes.FromRow
import Database.PostgreSQL.PQTypes.FromSQL
import Database.PostgreSQL.PQTypes.Format
import Database.PostgreSQL.PQTypes.Internal.C.Interface
import Database.PostgreSQL.PQTypes.Internal.C.Types
import Database.PostgreSQL.PQTypes.Internal.Utils
import Database.PostgreSQL.PQTypes.ToRow
import Database.PostgreSQL.PQTypes.ToSQL

newtype Composite a = Composite a
  deriving (Eq, Functor, Ord, Show, Typeable)

unComposite :: Composite a -> a
unComposite (Composite a) = a

type family CompositeRow t :: *

class (PQFormat t, FromRow (CompositeRow t)) => CompositeFromSQL t where
  toComposite :: CompositeRow t -> t

class (PQFormat t, ToRow (CompositeRow t)) => CompositeToSQL t where
  fromComposite :: t -> CompositeRow t

instance PQFormat t => PQFormat (Composite t) where
  pqFormat _ = pqFormat (undefined::t)

instance CompositeFromSQL t => FromSQL (Composite t) where
  type PQBase (Composite t) = Ptr PGresult
  fromSQL Nothing = unexpectedNULL
  fromSQL (Just res) = Composite
    <$> E.finally (toComposite <$> fromRow' res 0) (c_PQclear res)

instance CompositeToSQL t => ToSQL (Composite t) where
  type PQDest (Composite t) = PGparam
  toSQL (Composite comp) allocParam conv = allocParam $ \param -> do
    toRow' (fromComposite comp) allocParam param
    conv param