module UnitTests where

import Test.Hspec

import Sheet.Backend.Standard.Deps
import Sheet.Backend.Standard.Parsers
import Sheet.Backend.Standard.Types


allUnitTests :: IO ()
allUnitTests = do
  resolveDepsTests
  parseCellDefTests
  parsePosTests


parsePosTests :: IO ()
parsePosTests = hspec $ do
  describe "parse cell positions" $ do
    it "parseable" $ do
      parsePos "a1" `shouldBe` Just (1, 1)
      parsePos "a2" `shouldBe` Just (1, 2)
      parsePos "b1" `shouldBe` Just (2, 1)
      parsePos "b2" `shouldBe` Just (2, 2)
      parsePos "b10" `shouldBe` Just (2, 10)
      parsePos "aa10" `shouldBe` Just (27, 10)
      parsePos "ab10" `shouldBe` Just (28, 10)
      parsePos "ab11" `shouldBe` Just (28, 11)
    it "not parseable (empty)" $ do
      parsePos "" `shouldBe` Nothing
    it "not parseable (wrong order)" $ do
      parsePos "1a" `shouldBe` Nothing
    it "not parseable (missing row)" $ do
      parsePos "a" `shouldBe` Nothing
    it "not parseable (missing col)" $ do
      parsePos "1" `shouldBe` Nothing
    it "not parseable (bad trailing character)" $ do
      parsePos "a1a" `shouldBe` Nothing


parseCellDefTests :: IO ()
parseCellDefTests = hspec $ do
  describe "parse cell definitions" $ do
    it "let def" $ do
      parseCellDef "x = 4" `shouldBe` LetDef "x = 4"
      parseCellDef "x = 'a'" `shouldBe` LetDef "x = 'a'"
    it "import" $ do
      parseCellDef ":m ALibModule.hs" `shouldBe` Import "ALibModule.hs"
    it "load" $ do
      parseCellDef ":l ACustomModule.hs" `shouldBe` Load "ACustomModule.hs"
    it "IO statement" $ do
      parseCellDef "`function 'a' 3`" `shouldBe` IODef "function 'a' 3"
    it "language extension" $ do
      parseCellDef ":e SomeExt" `shouldBe` LanguageExtension "SomeExt"


resolveDepsTests :: IO ()
resolveDepsTests = hspec $ do
  describe "dependency resolver" $ do
    it "resolves to root only if no dependencies" $ do
      resolveDeps [
        ((0,0),[])
        ] `shouldBe` [(0,0)]
    it "resolves to root + root's dependencies (if no further deps)" $ do
      resolveDeps [
        ((0,0),[(0,1)]),
        ((0,1),[])
        ] `shouldBe` [(0,0),(0,1)]
      resolveDeps [
        ((0,0),[(0,1),(0,2)]),
        ((0,1),[]),
        ((0,2),[])
        ] `shouldSatisfy` \res ->
             res == [(0,0),(0,1),(0,2)]
          || res == [(0,0),(0,2),(0,1)]
    it "resolves to root + nested dependencies (simple: acyclic)" $ do
      resolveDeps [
        ((0,0),[(0,1)]),
        ((0,2),[(1,0)]),
        ((1,0),[])
        ] `shouldBe` [(0,0),(0,2),(1,0)]
      resolveDeps [
        ((0,0),[(0,1)]),
        ((0,2),[(1,0),(2,0)]),
        ((1,0),[]),
        ((2,0),[])
        ] `shouldSatisfy` \res ->
             res == [(0,0),(0,2),(1,0),(2,0)]
          || res == [(0,0),(0,2),(2,0),(1,0)]
    it "cyclic: intra looping cell (and dependencies of) is ignored" $ do
      resolveDeps [
        ((0,0),[(0,0)])
        ] `shouldBe` []
      resolveDeps [
        ((0,0),[(0,0)]),
        ((0,1),[])
        ] `shouldBe` [(0,1)]
    it "cyclic: intra looping cell (and dependencies of) is ignored" $ do
      resolveDeps [
        ((0,0),[(0,1),(0,0)]),
        ((0,1),[])
        ] `shouldBe` []
    it "cyclic: inter looping cells are ignored" $ do
      resolveDeps [
        ((0,0),[(0,1)]),
        ((0,1),[(0,0)])
        ] `shouldBe` []
      resolveDeps [
        ((0,0),[(0,1)]),
        ((0,1),[(0,0)]),
        ((0,2),[])
        ] `shouldBe` [(0,2)]
