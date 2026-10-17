defmodule NunkiWeb.HelpLive do
  @moduledoc """
  The manual, at `/help`, in English and Dutch: what Nunki is, joining,
  what it says and when, the hall screen, voices per system, and what to
  do when it is quiet when it should not be. Text only; nothing is read
  from the program, so it stays right when the program is the thing that
  is wrong.
  """
  use NunkiWeb, :live_view

  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, page_title: gettext("Help"))}

  @impl true
  def render(%{locale: "nl"} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} locale={@locale} page={:help}>
      <article id="manual" class="manual">
        <h1>Nunki, de omroeper van de zaal</h1>

        <section id="manual-what">
          <h2>Wat Nunki doet</h2>
          <p>
            Nunki leest de indeling voor zodra die in OpenPairings gepubliceerd is ("Bord 1: ... tegen ..."), en telt af naar het begin van de ronde: tien minuten, vijf minuten, één minuut, en "Ronde 3 begint nu". Het draait op een computer in de zaal met luidsprekers eraan, en spreekt met de stem van het besturingssysteem.
          </p>
          <p>
            Wat er omgeroepen wordt, beslis je in OpenPairings. Deze pagina is er om Nunki aan een toernooi te koppelen, de stem te kiezen en in te grijpen: nu voorlezen, stoppen, zelf een aftelling starten.
          </p>
        </section>

        <section id="manual-join">
          <h2>Een toernooi koppelen</h2>
          <ol>
            <li>
              Open in OpenPairings het toernooi, de pagina Omroeper, en druk op "Een omroeper toevoegen".
            </li>
            <li>
              Kopieer de link en plak hem op deze pagina in "Bij een toernooi aansluiten". Druk op Aansluiten.
            </li>
            <li>Het toernooi staat in de lijst. Een groene stip: de verbinding staat.</li>
          </ol>
          <p>
            De link werkt één keer en vijftien minuten lang. Verlopen? Maak een nieuwe. Een link voor een printstation (Polis) werkt hier niet, en wordt geweigerd voor hij opgebruikt raakt.
          </p>
        </section>

        <section id="manual-speech">
          <h2>Wat Nunki zegt, en wanneer</h2>
          <ul>
            <li>
              Een nieuwe ronde gepubliceerd: de indeling wordt voorgelezen, als "Lees de indeling voor als ze gepubliceerd wordt" aan staat. Wordt een ronde die al voorgelezen is daarna nog aangepast, dan leest Nunki ze niet vanzelf opnieuw voor; druk dan op "Nu voorlezen".
            </li>
            <li>
              Een aftelling, uit OpenPairings of van hier: op tien, vijf en één minuut, en op nul. Alleen de momenten die nog komen; wie op vijf minuten start, hoort geen tien.
            </li>
            <li>"Stop" zwijgt meteen en vergeet wat nog moest komen.</li>
          </ul>
          <p>
            De taal volgt het toernooi (de taal van het OpenPairings-account), tenzij je bij "Taal van de omroep" Engels of Nederlands kiest.
          </p>
        </section>

        <section id="manual-hall">
          <h2>Het zaalscherm</h2>
          <p>
            <a href="/hall">/hall</a>
            is een donker scherm voor een beamer of een tv: tijdens een aftelling de minuten in grote cijfers, anders de laatste indeling, en onderaan de zin die Nunki uitspreekt. De knop rechtsboven zet het scherm op volledig scherm. Met meer toernooien kies je er een met de knop "Zaalscherm" bij dat toernooi.
          </p>
          <p>
            Het scherm is een extraatje. Nunki spreekt ook als het niet openstaat.
          </p>
        </section>

        <section id="manual-voices">
          <h2>Stemmen</h2>
          <ul>
            <li>
              Windows: Engels is er altijd. Voor Nederlands voeg je de taal toe onder Instellingen, Tijd en taal, Spraak, en start je Nunki opnieuw.
            </li>
            <li>
              macOS: download een Nederlandse stem onder Systeeminstellingen, Toegankelijkheid, Gesproken materiaal.
            </li>
            <li>
              Linux: installeer espeak-ng. Het klinkt als een robot, maar wel een die op tijd is.
            </li>
          </ul>
          <p>
            Kies per taal een stem en druk op "Test de stem" om te horen hoe het klinkt in de zaal.
          </p>
        </section>

        <section id="manual-trouble">
          <h2>Als het stil blijft</h2>
          <ul>
            <li>
              Rode stip bij het toernooi: de reden staat ernaast. Nunki probeert het zelf opnieuw.
            </li>
            <li>
              "Geen stem": zie hierboven. Zonder stem kiest het systeem er zelf een, en dat is soms Engels dat Nederlands leest.
            </li>
            <li>
              Linux als dienst: zie de README over geluid. Start Nunki desnoods als de gebruiker die ingelogd is, met nunki.sh.
            </li>
          </ul>
        </section>
      </article>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} locale={@locale} page={:help}>
      <article id="manual" class="manual">
        <h1>Nunki, the hall announcer</h1>

        <section id="manual-what">
          <h2>What Nunki does</h2>
          <p>
            Nunki reads the pairings aloud as soon as they are published in OpenPairings ("Board 1: ... against ..."), and counts down to the start of the round: ten minutes, five minutes, one minute, and "Round 3 starts now". It runs on a computer in the hall with speakers attached, and speaks with the operating system's own voice.
          </p>
          <p>
            What is announced is decided in OpenPairings. This page is for joining Nunki to a tournament, choosing the voice and stepping in: read now, stop, start a countdown of your own.
          </p>
        </section>

        <section id="manual-join">
          <h2>Joining a tournament</h2>
          <ol>
            <li>
              In OpenPairings, open the tournament, the Hall announcer page, and press "Add an announcer".
            </li>
            <li>Copy the link and paste it into "Join a tournament" on this page. Press Join.</li>
            <li>The tournament is in the list. A green dot: the line is up.</li>
          </ol>
          <p>
            The link works once, for fifteen minutes. Expired? Make a new one. A print station's link (Polis) does not work here, and is refused before it gets used up.
          </p>
        </section>

        <section id="manual-speech">
          <h2>What Nunki says, and when</h2>
          <ul>
            <li>
              A new round published: the pairings are read, if "Read the pairings when they are published" is on. A round that was already read and is corrected afterwards is not read again by itself; press "Read now" for that.
            </li>
            <li>
              A countdown, from OpenPairings or from here: at ten, five and one minute, and at zero. Only the moments still ahead; start one at five minutes and there is no "ten".
            </li>
            <li>"Stop" is quiet at once and forgets what was still to come.</li>
          </ul>
          <p>
            The language follows the tournament (the OpenPairings account's language), unless you pick English or Nederlands under "Language of the announcements".
          </p>
        </section>

        <section id="manual-hall">
          <h2>The hall screen</h2>
          <p>
            <a href="/hall">/hall</a>
            is a dark screen for a projector or a TV: during a countdown the minutes in big digits, otherwise the latest pairings, and at the bottom the line Nunki is saying. The button at the top right makes it full screen. With more than one tournament, pick one with the "Hall screen" button beside it.
          </p>
          <p>
            The screen is an extra. Nunki speaks whether it is open or not.
          </p>
        </section>

        <section id="manual-voices">
          <h2>Voices</h2>
          <ul>
            <li>
              Windows: English is always there. For Dutch, add the language under Settings, Time & language, Speech, and restart Nunki.
            </li>
            <li>
              macOS: download a Dutch voice under System Settings, Accessibility, Spoken Content.
            </li>
            <li>Linux: install espeak-ng. It sounds like a robot, but a punctual one.</li>
          </ul>
          <p>Choose a voice per language and press "Test voice" to hear how it sounds in the hall.</p>
        </section>

        <section id="manual-trouble">
          <h2>When it stays quiet</h2>
          <ul>
            <li>
              A red dot by the tournament: the reason is beside it. Nunki tries again by itself.
            </li>
            <li>
              "No voice": see above. Without one the system picks its own, and that is sometimes English reading Dutch.
            </li>
            <li>
              Linux as a service: see the README on sound. If need be, run Nunki as the logged-in user, with nunki.sh.
            </li>
          </ul>
        </section>
      </article>
    </Layouts.app>
    """
  end
end
