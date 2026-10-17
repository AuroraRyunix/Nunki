defmodule Nunki.ScriptTest do
  @moduledoc "The words, in both languages, and the order a hall hears them in."

  use ExUnit.Case, async: true

  alias Nunki.Script

  @payload %{
    "round" => 3,
    "boards" => [
      %{
        "board" => "1",
        "white" => %{"name" => "Alpha, Ann", "spoken" => "Ann Alpha"},
        "black" => %{"name" => "Beta, Bob", "spoken" => "Bob Beta"}
      },
      %{"board" => "2", "white" => %{"name" => "Gamma, Cee"}, "black" => nil, "bye" => "pab"},
      %{
        "board" => "3",
        "white" => %{"name" => "Delta, Dee"},
        "black" => %{"name" => "Epsilon"}
      }
    ]
  }

  test "English: the header, the games white first, then the byes" do
    assert Script.pairings(@payload, "en") == [
             "Pairings for round 3 are published.",
             "Board 1: Ann Alpha against Bob Beta.",
             "Board 3: Dee Delta against Epsilon.",
             "Cee Gamma has a bye."
           ]
  end

  test "Dutch: the same, in Dutch" do
    assert Script.pairings(@payload, "nl") == [
             "De indeling van ronde 3 is bekend.",
             "Bord 1: Ann Alpha tegen Bob Beta.",
             "Bord 3: Dee Delta tegen Epsilon.",
             "Cee Gamma is deze ronde vrij."
           ]
  end

  test "an unknown locale is English" do
    assert hd(Script.pairings(@payload, "fr")) == "Pairings for round 3 are published."
  end

  test "the countdown's milestones in English" do
    assert Script.milestone(:ten, 4, "en") == "Round 4 starts in ten minutes."
    assert Script.milestone(:five, 4, "en") == "Round 4 starts in five minutes."

    assert Script.milestone(:one, 4, "en") ==
             "Round 4 starts in one minute. Please go to your board."

    assert Script.milestone(:zero, 4, "en") == "Round 4 starts now. Please start the clocks."
  end

  test "the countdown's milestones in Dutch, with je" do
    assert Script.milestone(:ten, 4, "nl") == "Ronde 4 begint over tien minuten."
    assert Script.milestone(:five, 4, "nl") == "Ronde 4 begint over vijf minuten."
    assert Script.milestone(:one, 4, "nl") == "Ronde 4 begint over één minuut. Ga naar je bord."
    assert Script.milestone(:zero, 4, "nl") == "Ronde 4 begint nu. Zet de klokken in gang."
  end

  test "the test line exists in both" do
    assert Script.test_line("en") =~ "announcements"
    assert Script.test_line("nl") =~ "omroep"
  end

  test "a name without spoken is turned round; one without a comma stays" do
    assert Script.spoken(%{"name" => "Carlsen, Magnus"}) == "Magnus Carlsen"
    assert Script.spoken(%{"name" => "Hou Yifan"}) == "Hou Yifan"
    assert Script.spoken(%{"spoken" => "", "name" => "X, Y"}) == "Y X"
    assert Script.spoken(nil) == "?"
  end
end
