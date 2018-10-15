{-|
Module      : SpreedSheet.Sheet
Description : An experimental application of the spreadsheet API
Stability   : experimental
-}
{-# LANGUAGE TypeSynonymInstances, FlexibleInstances, MultiParamTypeClasses, FlexibleContexts,
             ScopedTypeVariables #-}
module Sheet.Backend.SheetImpl
      ( module Sheet.Backend.SheetImpl
      , module Sheet.Backend.Types
      ) where

import Sheet.Backend.Types

import Data.Maybe

import Control.Monad
import Control.Concurrent.STM
import Control.Monad.Reader

import qualified Data.Map as M
import qualified Data.Set as S

import Sheet.Backend.SheetAbstr

import Debug.Trace

import Lambda.Lambda

instance Spreadsheet (Sheet StringCell) (CellT StringCell) StringCell String (State (Sheet StringCell)) (Reader (M.Map String StringCell)) where
  updateEvals = do
    s <- get
    mapM_ updateEval ((M.toList s))
  getCell p = do
    s <- get
    return (M.lookup p s)
  setCell p c = do
    s <- get
    put (M.insert p c s)

-- | A naive way of fully (re)evaluating the cell expressions. If an
-- evaluation differs from the prior evaluation, the entire sheet will again
-- be evaluated. This is repeated until none of the evaluations differ from
-- the prior evaluation.
updateEval
  :: (Show v1, Cell (CellT t) (LC v1) v m,
      Spreadsheet s (CellT StringCell) StringCell String m1 (Reader (M.Map String (LC String)))) =>
     (Pos, CellT t) -> m1 ()
updateEval (p, c) =
  do
    let freshParse = parseCell c
    s <- trace ("Updating: " ++ show p) get
    mC <- getCell p
    let refs = case (getEval freshParse) of
                Just e  -> trace ("Scanning refs in: " ++ show e) scanCellRefs e
                Nothing -> trace "No evaluation" []
    refCs <- catMaybes
          <$> map preCat
          <$> zip refs
          <$> trace ("Found refs; " ++ show refs) mapM getCell refs
    let refEs = map (\(p,c :: CellT StringCell) -> (p,getEval c)) refCs
    let mC' = mC >>= \c -> return $ parseCell c
        globVars = mapMaybe (\(p,mE) -> mE >>= \e -> trace ("cRefs: " ++ show p) return (cRefPos2Var p, e)) refEs
        mC'' = trace ("test: " ++ show globVars) mC' >>= \c' -> return $ runReader (evalCell c') (M.fromList globVars)
        oldEval = mC >>= \c -> getEval c
        newEval = mC'' >>= \c'' -> getEval c''
    if (oldEval == newEval)
      then return ()
      else let c'' = case newEval of
                       Just e -> trace ("Updating e to: " ++ show e) c {uFlag = True, lExpr = Just $ e}
                       Nothing -> c {uFlag = True, lExpr = Nothing}
           in setCell p c'' >> updateEvals
  where preCat (p,Just j) = Just (p, j)
        preCat (p,Nothing) = Nothing


instance Cell (CellT StringCell) StringCell String (Reader (Env String StringCell)) where
  evalCell c@CellT {lExpr = maybeE} =
    do
      env <- ask
      case maybeE of
        Just e  -> (\e' -> c {lExpr = Just e'}) <$> evalExpr e
        Nothing -> return c
  parseCell c@CellT {str = code} =
    c {lExpr = parseExpr code}
  getEval = lExpr
  getText = str

-- | 'isInBox' if the position is inside the box 'Nothing' is returned.
-- Otherwise, it returns the offset of the position towards the box.
isInBox :: Pos -> (Pos,Pos) -> Maybe Pos
isInBox (r,c) ((rL, cL), (rH, cH))
  = let rOffset = if r < rL
                    then r - rL
                    else if r > rH
                      then r - rH
                      else 0
        cOffset = if c < cL
                    then c - cL
                    else if c > cH
                      then c - cH
                      else 0
    in if rOffset == 0 && cOffset == 0
        then Nothing
        else Just (rOffset,cOffset)

-- | 'grabUpdatedCells' filters out all cells that have not changed.
grabUpdatedCells :: (Var v, Expr e v (Reader (Env v e))) => Sheet e -> Sheet e
grabUpdatedCells = M.filter uFlag

-- | 'resetUpdateFields' removes the update flags of all cells.
resetUpdateFields :: (Var v, Expr e v (Reader (Env v e))) => Sheet e -> Sheet e
resetUpdateFields = M.map (\c -> c {uFlag = False})

-- | Subtraction on 'Pos' variables.
posSubtr :: Pos -> Pos -> Pos
posSubtr (r1,c1) (r2,c2) = (r1-r2,c1-c2)

-- | Addition on 'Pos' variables.
posAdd :: Pos -> Pos -> Pos
posAdd (r1,c1) (r2,c2) = (r1+r2,c1+c2)

-- | 'sliceList' grabs a part of list 'xs' that ranges from index 'from' to
-- index 'to'.
sliceList :: Int -> Int -> [a] -> [a]
sliceList from to xs = take (to - from + 1) (drop from xs)

-- | 'subLists' slices a list 'xs', where each slice has a length of at most
-- 'i'.
subLists :: Int -> [a] -> [[a]]
subLists i xs = let is = [0,i..(length xs - 1)]
                in map (\i' -> sliceList i' (i'+i-1) xs) is

initSheet :: (Var v, Expr e v (Reader (Env v e))) => Sheet e
initSheet = M.empty

-- | Helper function to conveniently obtain a 'CellT e' from the 'Sheet e'.
getSheetCell :: (Var v, Expr e v (Reader (Env v e))) => Pos -> Sheet e -> CellT e
getSheetCell pos cs
  = M.findWithDefault emptyCell pos cs

emptyCell :: (Var v, Expr e v (Reader (Env v e))) => CellT e
emptyCell = CellT "" Nothing False

-- | 'scanCellRefs' obtains all references that are present in an
-- expression. This is for example used to find out which global variables
-- need to be added to an expression prior to evaluating it.
scanCellRefs :: LC v -> [Pos]
scanCellRefs (CVar p)    = [p]
scanCellRefs (Lam _ e)   = scanCellRefs e
scanCellRefs (App e1 e2) = scanCellRefs e1 ++ scanCellRefs e2
scanCellRefs _ = []
