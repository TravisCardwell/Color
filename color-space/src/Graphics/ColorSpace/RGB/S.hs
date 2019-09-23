{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveTraversable #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NegativeLiterals #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
-- |
-- Module      : Graphics.ColorSpace.RGB.S
-- Copyright   : (c) Alexey Kuleshevich 2018-2019
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Graphics.ColorSpace.RGB.S
  ( pattern PixelRGB
  --, ToRGB(..)
  , RGB
  --, RGBA
  , Pixel
  , Illuminant(..)
  -- , npm
  -- , inpm
  , npmStandard
  , inpmStandard
  ) where

import Foreign.Storable
import qualified Graphics.ColorModel.RGB as CM
import Graphics.ColorModel.Internal
import Graphics.ColorModel.Helpers
import Graphics.ColorSpace.Internal
import Graphics.ColorSpace.Algebra
import Graphics.ColorSpace.CIE1931.Illuminants
import Prelude hiding (map)
import Data.Typeable
import Data.Coerce



-- | The most common @sRGB@ color space with the default `D65` illuminant
type RGB = SRGB 'D65


-- | The most common @sRGB@ color space
data SRGB (i :: k)


newtype instance Pixel (SRGB i) e = PixelSRGB (Pixel CM.RGB e)
  deriving (Eq, Functor, Applicative, Foldable, Traversable, Storable)

pattern PixelRGB :: e -> e -> e -> Pixel RGB e
pattern PixelRGB r g b = PixelSRGB (CM.PixelRGB r g b)
{-# COMPLETE PixelRGB #-}

-- -- | Conversion to `RGB` color space.
-- class ColorSpace cs e => ToRGB cs e where
--   -- | Convert to an `RGB` pixel.
--   toPixelRGB :: Pixel cs e -> Pixel RGB Double

instance Show e => Show (Pixel (SRGB i) e) where
  showsPrec _ (PixelSRGB (CM.PixelRGB r g b)) =
    showsP "sRGB:" -- ++ show i
    (shows3 r g b)

-- | sRGB defined in 'Graphics.ColorSpace.RGB.S'
instance (Typeable i, Typeable k, Elevator e) => ColorModel (SRGB (i :: k)) e where
  type Components (SRGB i) e = (e, e, e)
  toComponents = toComponents . coerce
  {-# INLINE toComponents #-}
  fromComponents = coerce . fromComponents
  {-# INLINE fromComponents #-}

instance Elevator e => ColorSpace RGB e where
  toPixelXYZ (PixelRGB r g b) =
    fromV3 PixelXYZ (multM3x3byV3 (unNPM npmD65) (toV3 r g b))
  {-# INLINE toPixelXYZ #-}
  fromPixelXYZ (PixelXYZ x y z) =
    fromV3 PixelRGB (multM3x3byV3 (unINPM inpmD65) (toV3 x y z))
  {-# INLINE fromPixelXYZ #-}

inpmApply :: (Elevator e1, Elevator e2) => (e1 -> e1 -> e1 -> a) -> INPM cs i -> Pixel XYZ e2 -> a
inpmApply f inpm' (PixelXYZ x y z) = fromV3 f (multM3x3byV3 (unINPM inpm') (toV3 x y z))


class Illuminant i => ComputeRGB cs i | cs -> i where
  chromaticity :: Pixel cs e -> Chromaticity i
  chroma :: Proxy cs -> Chromaticity i
  mkRGB :: Pixel CM.RGB e -> Pixel cs e
  unRGB :: Pixel cs e -> Pixel CM.RGB e

  --rgbFromV3 :: V3 -> Pixel cs e

instance Illuminant i => ComputeRGB (SRGB i) i where
  chromaticity _ = Chromaticity (Primary 0.64 0.33)
                                (Primary 0.30 0.60)
                                (Primary 0.15 0.06)
  chroma _ = Chromaticity (Primary 0.64 0.33)
                          (Primary 0.30 0.60)
                          (Primary 0.15 0.06)
  mkRGB = coerce
  unRGB = coerce

-- toPixelComputedXYZ' ::
--      forall cs i e.
--      ( Coercible  (Pixel cs e) (Pixel CM.RGB e)
--      , Chroma cs i
--      , Components cs e ~ (e, e, e)
--      , ColorSpace cs e
--      )
--   => Pixel cs e
--   -> Pixel XYZ Double
-- toPixelComputedXYZ' px = fromV3 PixelXYZ (multM3x3byV3 (unNPM npm') (toV3 r g b))
--   where
--     npm' = npmCompute (chroma (Proxy :: Proxy cs)) :: NPM cs i
--     (CM.PixelRGB r g b) = coerce px


rgb2xyz ::
     forall cs i e. (ComputeRGB cs i, ColorModel cs e)
  => Pixel cs e
  -> Pixel XYZ Double
rgb2xyz px = fromV3 PixelXYZ (multM3x3byV3 (unNPM npm') (toV3 r g b))
  where
    !npm' = npmCompute (chromaticity px) :: NPM cs i
    CM.PixelRGB r g b = unRGB px

fromPixelComputedXYZ ::
     forall cs i e. (ComputeRGB cs i, ColorModel cs e)
  => Pixel XYZ Double
  -> Pixel cs e
fromPixelComputedXYZ (PixelXYZ x y z) = px
  where
    !px = mkRGB $ fromV3 CM.PixelRGB (multM3x3byV3 (unINPM inpm') (toV3 x y z))
    !inpm' = inpmCompute (chromaticity px) :: INPM cs i

npmSRGB :: forall i . Illuminant i => NPM (SRGB i) i
npmSRGB = npmCompute (chroma (Proxy :: Proxy (SRGB i)))


-- memoized
npmSRGB' :: NPM (SRGB D65) D65
npmSRGB' = npmCompute (chroma (Proxy :: Proxy (SRGB D65)))



-- | Normalized primary matrix for sRGB with D65 white point.
npmD65 :: NPM (SRGB 'D65) 'D65
npmD65 = NPM $ M3x3 (V3 0.41239079926595923 0.3575843393838781 0.1804807884018344)
                    (V3 0.21263900587151022 0.7151686787677562 0.0721923153607337)
                    (V3 0.01933081871559182 0.1191947797946260 0.9505321522496610)

inpmD65 :: INPM RGB 'D65
inpmD65 = INPM $ M3x3 (V3  3.2409699419045235 -1.5373831775700944 -0.4986107602930038)
                      (V3 -0.9692436362808795  1.87596750150772    0.0415550574071757)
                      (V3  0.0556300796969936 -0.20397695888897646 1.0569715142428782)


npmStandard :: M3x3
npmStandard = M3x3 (V3 0.4124 0.3576 0.1805)
                   (V3 0.2126 0.7152 0.0722)
                   (V3 0.0193 0.1192 0.9505)

-- | Normalized primary matrix for conversion of XYZ to linear sRGB, as specified in @IEC
-- 61966-2-1:1999@ standard
--
-- >>> import Graphics.ColorSpace.RGB.S as SRGB
-- >>> SRGB.inpmStandard
-- [ [ 3.2406000,-1.5372000,-0.4986000]
-- , [-0.9689000, 1.8758000, 0.0415000]
-- , [ 0.0557000,-0.2040000, 1.0570000] ]
--
-- @since 0.1.0
inpmStandard :: M3x3
inpmStandard = M3x3 (V3  3.2406 -1.5372 -0.4986)
                    (V3 -0.9689  1.8758  0.0415)
                    (V3  0.0557 -0.2040  1.0570)



-- m3x3' :: Elevator e => (e -> e -> e -> b) -> V3 -> V3 -> V3 -> V3 -> b
-- m3x3' f (V3 m00 m01 m02) (V3 m10 m11 m12) (V3 m20 m21 m22) (V3 v0 v1 v2) =
--   f (fromDouble (m00 * v0 + m01 * v0 + m02 * v0))
--     (fromDouble (m10 * v1 + m11 * v1 + m12 * v1))
--     (fromDouble (m20 * v2 + m21 * v2 + m22 * v2))
-- {-# INLINE m3x3' #-}


-- instance Functor (Pixel RGB) where
--   fmap f (PixelRGB r g b) = PixelRGB (f r) (f g) (f b)
--   {-# INLINE fmap #-}

-- instance Applicative (Pixel RGB) where
--   pure !e = PixelRGB e e e
--   {-# INLINE pure #-}
--   (PixelRGB fr fg fb) <*> (PixelRGB r g b) = PixelRGB (fr r) (fg g) (fb b)
--   {-# INLINE (<*>) #-}

-- instance Foldable (Pixel RGB) where
--   foldr f !z (PixelRGB r g b) = foldr3 f z r g b
--   {-# INLINE foldr #-}

-- instance Traversable (Pixel RGB) where
--   traverse f (PixelRGB r g b) = traverse3 PixelRGB f r g b
--   {-# INLINE traverse #-}

-- instance Storable e => Storable (Pixel RGB e) where
--   sizeOf = sizeOfN 3
--   {-# INLINE sizeOf #-}
--   alignment = alignmentN 3
--   {-# INLINE alignment #-}
--   peek = peek3 PixelRGB
--   {-# INLINE peek #-}
--   poke p (PixelRGB r g b) = poke3 p r g b
--   {-# INLINE poke #-}

------------
--- RGBA ---
------------


-- -- | @sRGB@ color space with Alpha channel.
-- data RGBA


-- data instance Pixel RGBA e = PixelRGBA !e !e !e !e deriving (Eq, Ord)


-- instance Show e => Show (Pixel RGBA e) where
--   showsPrec _ (PixelRGBA r g b a) = showsP "sRGBA" (shows4 r g b a)


-- instance Elevator e => ColorSpace RGBA e where
--   type Components RGBA e = (e, e, e, e)

--   toComponents (PixelRGBA r g b a) = (r, g, b, a)
--   {-# INLINE toComponents #-}
--   fromComponents (r, g, b, a) = PixelRGBA r g b a
--   {-# INLINE fromComponents #-}

-- instance Elevator e => AlphaSpace RGBA e where
--   type Opaque RGBA = RGB
--   getAlpha (PixelRGBA _ _ _ a) = a
--   {-# INLINE getAlpha #-}
--   addAlpha !a (PixelRGB r g b) = PixelRGBA r g b a
--   {-# INLINE addAlpha #-}
--   dropAlpha (PixelRGBA r g b _) = PixelRGB r g b
--   {-# INLINE dropAlpha #-}


-- instance Functor (Pixel RGBA) where
--   fmap f (PixelRGBA r g b a) = PixelRGBA (f r) (f g) (f b) (f a)
--   {-# INLINE fmap #-}

-- instance Applicative (Pixel RGBA) where
--   pure !e = PixelRGBA e e e e
--   {-# INLINE pure #-}
--   (PixelRGBA fr fg fb fa) <*> (PixelRGBA r g b a) = PixelRGBA (fr r) (fg g) (fb b) (fa a)
--   {-# INLINE (<*>) #-}

-- instance Foldable (Pixel RGBA) where
--   foldr f !z (PixelRGBA r g b a) = foldr4 f z r g b a
--   {-# INLINE foldr #-}

-- instance Traversable (Pixel RGBA) where
--   traverse f (PixelRGBA r g b a) = traverse4 PixelRGBA f r g b a
--   {-# INLINE traverse #-}

-- instance Storable e => Storable (Pixel RGBA e) where
--   sizeOf = sizeOfN 4
--   {-# INLINE sizeOf #-}
--   alignment = alignmentN 4
--   {-# INLINE alignment #-}
--   peek = peek4 PixelRGBA
--   {-# INLINE peek #-}
--   poke p (PixelRGBA r g b a) = poke4 p r g b a
--   {-# INLINE poke #-}
