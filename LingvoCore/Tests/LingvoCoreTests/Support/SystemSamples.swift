import LingvoCore

/// Texts that `DCSCopyTextDefinition` returned on macOS for these words (New Oxford American Dictionary).
/// The long entries are cut after a few senses; the cut never touches the part under test.
enum SystemSamples {
    // swiftlint:disable:next line_length
    static let mumpsimus = "mumpsimus mump·si·mus | ˈməm(p)səməs | noun (plural mumpsimuses) a traditional custom or notion adhered to although shown to be unreasonable. • a person who obstinately adheres to unreasonable customs or notions. ORIGIN mid 16th century: erroneously for Latin sumpsimus in quod in ore sumpsimus ‘which we have taken into the mouth’ (from the Eucharist), in allusion to the story of an illiterate priest who, when corrected for reading quod in ore mumpsimus, replied ‘I will not change my old mumpsimus for your new sumpsimus’."

    // swiftlint:disable:next line_length
    static let skedaddle = "skedaddle ske·dad·dle | skəˈdad(ə)l | verb [no object] informal depart quickly or hurriedly; run away: when he saw us, he skedaddled. ORIGIN mid 19th century: of unknown origin."

    // swiftlint:disable:next line_length
    static let petrichor = "petrichor pet·ri·chor | ˈpetrīˌkôr | noun a pleasant smell that frequently accompanies the first rain after a long period of warm, dry weather: other than the petrichor emanating from the rapidly drying grass, there was not a trace of evidence that it had rained at all. ORIGIN 1960s: blend of petro- ‘relating to rocks’ (the smell is believed to be caused by a liquid mixture of organic compounds which collects in the ground) and ichor."

    // swiftlint:disable:next line_length
    static let persnickety = "persnickety per·snick·et·y | pərˈsnikədē | adjective North American English informal placing too much emphasis on trivial or minor details; fussy: she's very persnickety about her food. • requiring a particularly precise or careful approach: it's hard to find a film more persnickety and difficult to use than black-and-white infrared. ORIGIN late 19th century: alteration of pernickety."

    // swiftlint:disable:next line_length
    static let codswallop = "codswallop cods·wal·lop | ˈkädzˌwäləp | noun British English informal nonsense: I think that's a right load of old codswallop. ORIGIN 1920s (in old sense ‘overly talkative woman, gossip’): probably an alteration of cod walloper ‘person who deals in or handles fish’, also ‘foolish person’."

    // swiftlint:disable:next line_length
    static let ephemeral = "ephemeral e·phem·er·al | əˈfem(ə)rəl | adjective lasting for a very short time: fashions are ephemeral. • (chiefly of plants) having a very short life cycle: chickweed is an ephemeral weed, producing several generations in one season. noun an ephemeral plant: ephemerals avoid the periods of drought as seeds. DERIVATIVES ephemerality | əˌfem(ə)ˈralədē | noun ORIGIN late 16th century: from Greek ephēmeros (see ephemera) + -al."

    // swiftlint:disable:next line_length
    static let reluctant = "reluctant re·luc·tant | rəˈləkt(ə)nt | adjective unwilling and hesitant; disinclined: [with infinitive] : she seemed reluctant to discuss the matter. ORIGIN early 17th century (in the sense ‘offering opposition’): from Latin reluctant- ‘struggling against’, from the verb reluctari, from re- (expressing intensive force) + luctari ‘to struggle’."

    // The start of the long entry: the first sense has several examples, separated by bars.
    // swiftlint:disable:next line_length
    static let run = "run | rən | verb (runs) (, running | ˈrəniNG |) (past; ran | ran |) (past participle; run | rən |) 1 [no object] move at a speed faster than a walk, never having both or all the feet on the ground at the same time: the dog ran across the road | she ran the last few yards, breathing heavily | he hasn't paid for his drinks—run and catch him. • run as a sport or for exercise: I run every morning."

    // The dictionary answers a query with the closest entry it has: "colour" gives "unicolor".
    // swiftlint:disable:next line_length
    static let unicolor = "unicolor u·ni·col·or | ˈyo͞onəˌkələr | (unicolored) (British English -colour) (British English -coloured) adjective of one color. "

    // swiftlint:disable:next line_length
    static let church = "church | CHərCH | noun a building used for public Christian worship: they came to church with me. • (Church) a particular Christian organization."
    // swiftlint:disable:next line_length
    static let rhythm = "rhythm | ˈriT͟Həm | noun a strong, regular, repeated pattern of movement or sound: Ruth listened to the rhythm of his breathing."
    // swiftlint:disable:next line_length
    static let book = "book | bo͝ok | noun 1 a written or printed work consisting of pages glued or sewn together along one side and bound in covers: a book of selected poems."
    // swiftlint:disable:next line_length
    static let moon = "moon | mo͞on | noun (the moon or the Moon) the natural satellite of the earth, visible (chiefly at night) by reflected light from the sun: there was no moon."
    static let cute = "cute | kyo͞ot | adjective 1 appealing in a pretty or endearing way: a cute kitten | the baby was so cute."
    static let hour = "hour | ˈou(ə)r | noun 1 a period of time equal to a twenty-fourth part of a day and night and divided into 60 minutes."
    static let judge = "judge | jəj | noun a public official appointed to decide cases in a court of law."
    static let boy = "boy | boi | noun 1 a male child or adolescent: a four-year-old boy."
    static let thing = "thing | THiNG | noun 1 an object that one need not, cannot, or does not wish to give a specific name to."
    static let aunt = "aunt | ant, änt | noun the sister of one's father or mother."
    static let fire = "fire | ˈfī(ə)r | noun 1 combustion or burning, in which substances combine chemically with oxygen from the air."
    static let sure = "sure | SHo͝or, SHər, SHôr | adjective confident in what one thinks or knows."
    static let yellow = "yellow yel·low | ˈyelō | adjective 1 of the color between green and orange in the spectrum: a yellow dress."

    static let garbage = "💥 not a dictionary entry at all | | |"
}

/// A system dictionary that answers from a table; a word it lacks has no definition.
struct FakeSystemDictionary: SystemDictionary {
    let definitions: [String: String]

    func definition(of word: String) -> String? {
        definitions[word.lowercased()]
    }
}
