module Sheet.Frontend.Types where

import Sheet.Backend.Standard

-- | 'UISheet' defines the spreadsheet type. The functions in this UI
-- submodule pass a value of this datatype along in a statewise matter.
data UISheet = UISheet { sheetCells  :: S
                       , sheetCursor :: Pos
                       , sheetOffset :: Pos }

initUISheet =
  UISheet {
    sheetCells = initSheet,
    sheetCursor = (0,0),
    sheetOffset = (0,0)
  }
