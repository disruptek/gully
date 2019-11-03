import options
import strutils
import streams
import unittest2

import gully

var
  recipe = createDefaultRecipe()

suite "mutations":

  test "MaxWidth":
    let
      doc = recipe.newDocument("""# a line that is too long                                                                                    boop
        # a line that is just right""" & "\n")
    check doc.len == 2
    check recipe[MaxWidth].score(doc).get < 0.8

  test "Flow":
    let
      doc = recipe.newDocument("""
      a line that isn't too long      # but lacks flow
      a line that isn't too long    # but lacks flow
      a line that isn't too long  # with fine flow
      """ & "\n")
    check recipe[Flow].score(doc).get <= 0.75

  test "Padding":
    let
      doc = recipe.newDocument("""
      a line that isn't too long# but lacks padding
      a line that isn't too long # but lacks padding
      a line that isn't too long  # with fine padding
      """ & "\n")
    check recipe[Padding].score(doc).get < 0.65
