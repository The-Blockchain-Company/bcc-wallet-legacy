{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE LambdaCase    #-}

module Bcc.Wallet.API.Request (
    RequestParams (..)
  -- * Handly re-exports
  , module Bcc.Wallet.API.Request.Pagination
  , module Bcc.Wallet.API.Request.Filter
  , module Bcc.Wallet.API.Request.Sort
  ) where


import           Formatting (bprint, build, (%))
import           Pos.Infra.Util.LogSafe (BuildableSafeGen (..),
                     deriveSafeBuildable)

import           Bcc.Wallet.API.Request.Filter
import           Bcc.Wallet.API.Request.Pagination (PaginationMetadata (..),
                     PaginationParams)
import           Bcc.Wallet.API.Request.Sort

data RequestParams = RequestParams
    { rpPaginationParams :: PaginationParams
    -- ^ The pagination-related parameters
    }

deriveSafeBuildable ''RequestParams
instance BuildableSafeGen RequestParams where
    buildSafeGen _sl RequestParams{..} =
        bprint ("pagination: "%build) rpPaginationParams
