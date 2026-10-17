defmodule Nunki.SpeakerTest do
  @moduledoc "One line at a time, in order, and Stop means stop - all with the fake voice."

  use Nunki.Case, async: false

  alias Nunki.Speaker

  test "lines are said one after the other, in order, in the language asked" do
    Speaker.say(["one", "two", "three"], "nl")
    eventually(fn -> length(Fake.utterances()) == 3 end)

    assert Fake.texts() == ["one", "two", "three"]
    assert Enum.all?(Fake.utterances(), &(&1.lang == "nl"))
    # The first Dutch voice the fake has, since nothing was chosen.
    assert hd(Fake.utterances()).voice == "Fake Nederlands"
    eventually(fn -> not Speaker.speaking?() end)
  end

  test "a chosen voice is used while the system has it" do
    Nunki.Store.put_setting("voices", %{"nl" => "Fake Vlaams"})
    Speaker.say(["hallo"], "nl")
    eventually(fn -> Fake.utterances() != [] end)
    assert hd(Fake.utterances()).voice == "Fake Vlaams"
  end

  test "only one line is said at a time; the rest waits" do
    Fake.hold()
    Speaker.say(["first", "second"], "en")
    eventually(fn -> Speaker.status().speaking? end)

    assert %{line: "first", queued: 1} = Speaker.status()
    assert Fake.texts() == ["first"]

    Fake.finish()
    eventually(fn -> Fake.texts() == ["first", "second"] end)
    Fake.finish()
    eventually(fn -> not Speaker.speaking?() end)
  end

  test "stop ends the line being said and forgets the queue" do
    Fake.hold()
    Speaker.say(["first", "second", "third"], "en")
    eventually(fn -> Speaker.status().speaking? end)

    Speaker.stop()
    assert %{speaking?: false, queued: 0, line: nil} = Speaker.status()

    # Nothing more is said after a stop.
    Speaker.say(["after"], "en")
    eventually(fn -> List.last(Fake.texts()) == "after" end)
    refute "second" in Fake.texts()
  end

  test "every change is broadcast for the pages and the links" do
    Nunki.subscribe()
    Speaker.say(["hello"], "en")
    assert_receive {:speaker, %{speaking?: true, line: "hello"}}
    assert_receive {:speaker, %{speaking?: false}}
  end
end
