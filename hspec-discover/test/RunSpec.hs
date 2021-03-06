module RunSpec (main, spec) where

import           Test.Hspec.Meta

import           Control.Applicative
import           System.IO
import           System.Directory
import           System.FilePath
import           Data.List (intercalate, sort)

import           Run

main :: IO ()
main = hspec spec

withTempFile :: (FilePath -> IO a) -> IO a
withTempFile action = do
  dir <- getTemporaryDirectory
  (file, h) <- openTempFile dir ""
  hClose h
  action file <* removeFile file


spec :: Spec
spec = do
  describe "run" $ do
    it "generates test driver" $ withTempFile $ \f -> do
      run ["hspec-discover/test-data/nested-spec/Spec.hs", "", f]
      readFile f `shouldReturn` unlines [
          "{-# LINE 1 \"hspec-discover/test-data/nested-spec/Spec.hs\" #-}module Main where"
        , "import qualified Foo.Bar.BazSpec"
        , "import qualified Foo.BarSpec"
        , "import qualified FooSpec"
        , "import Test.Hspec"
        , "main :: IO ()"
        , "main = hspec $ describe \"Foo.Bar.Baz\" Foo.Bar.BazSpec.spec >> describe \"Foo.Bar\" Foo.BarSpec.spec >> describe \"Foo\" FooSpec.spec"
        ]

    it "generates test driver for an empty directory" $ withTempFile $ \f -> do
      run ["hspec-discover/test-data/empty-dir/Spec.hs", "", f]
      readFile f `shouldReturn` unlines [
          "{-# LINE 1 \"hspec-discover/test-data/empty-dir/Spec.hs\" #-}module Main where"
        , "import Test.Hspec"
        , "main :: IO ()"
        , "main = hspec $ return ()"
        ]

  describe "getFilesRecursive" $ do
    it "recursively returns all file entries of a given directory" $ do
      getFilesRecursive "hspec-discover/test-data" `shouldReturn` sort [
          "empty-dir/Foo/Bar/Baz/.placeholder"
        , "nested-spec/Foo/Bar/BazSpec.hs"
        , "nested-spec/Foo/BarSpec.hs"
        , "nested-spec/FooSpec.hs"
        ]

  describe "fileToSpec" $ do
    it "converts path to spec name" $ do
      fileToSpec "FooSpec.hs" `shouldBe` Just "Foo"

    it "rejects spec with empty name" $ do
      fileToSpec "Spec.hs" `shouldBe` Nothing

    it "works for lhs files" $ do
      fileToSpec "FooSpec.lhs" `shouldBe` Just "Foo"

    it "returns Nothing for invalid spec name" $ do
      fileToSpec "foo" `shouldBe` Nothing

    context "when path has directory component" $ do
      it "converts path to spec name" $ do
        fileToSpec ("Foo" </> "Bar" </> "BazSpec.hs") `shouldBe` Just "Foo.Bar.Baz"

      it "rejects spec with empty name" $ do
        fileToSpec ("Foo" </> "Bar" </> "Spec.hs") `shouldBe` Nothing

  describe "findSpecs" $ do
    it "finds specs" $ do
      findSpecs "hspec-discover/test-data/nested-spec/Spec.hs" `shouldReturn` ["Foo.Bar.Baz","Foo.Bar","Foo"]

  describe "driverWithFormatter" $ do
    it "generates a test driver that uses a custom formatter" $ do
      driverWithFormatter False "Some.Module.formatter" "" `shouldBe` intercalate "\n" [
          "import Test.Hspec"
        , "import Test.Hspec.Runner"
        , "import qualified Some.Module"
        , "main :: IO ()"
        , "main = hspecWithFormatter Some.Module.formatter $ "
        ]

  describe "moduleName" $ do
    it "returns the module name of an fully qualified identifier" $ do
      moduleName "Some.Module.someId" `shouldBe` "Some.Module"

  describe "importList" $ do
    it "generates imports for a list of specs" $ do
      importList ["Foo", "Bar"] "" `shouldBe` unlines [
          "import qualified FooSpec"
        , "import qualified BarSpec"
        ]
