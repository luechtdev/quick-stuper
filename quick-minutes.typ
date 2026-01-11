#let noun(it) = [#text(features: ("smcp",), tracking: 0.025em)[#it]] //small caps with proper tracking
#let versal(it) = [#text(tracking: 0.125em, number-type: "lining")[#upper[#it]]] //all caps with proper tracking
#let lang(it, content) = [#text(
    lang: it,
    style: "italic",
  )[#content]] 

#let stuper(
  // Event info
  body-name: none,
  event-name: none,
  date: none,

  // People
  people: (),
  present: (),
  online: (),
  list-votes: (:),

  chairperson: none,
  secretary: none,
  location: none,
  awareness: none,
  cosigner: none,
  cosigner-name: none,

  logo: none,
  long-toc: false,
  timestamp-margin: 10pt,
  line-numbering: 10,
  fancy-decisions: true,
  indent-decisions: false,
  fancy-dialogue: false,
  hole-mark: true,
  separator-lines: true,
  number-present: false,
  show-arrival-time: false,
  display-all-warnings: false,
  hide-warnings: false,
  warning-color: red,
  enable-help-text: true,
  body,
) = {
  // Constants
  let status-present = "present"
  let status-away = "away"
  let status-away-perm = "away-perm"
  let status-online = "online"
  let status-none = "none"

  // Variables
  let warnings = state("warnings", (:))
  let signing = false
  let all = state("all", ())
  let pres = state("pres", ())
  let away = state(status-away, ())
  let away-perm = state(status-away-perm, ())
  let onl = state(status-online, ())
  
  // Times
  let last-time = state("last-time", none)
  let start-time = state("start-time", none)

  // Defaults
  let item-numbering = (..nums) => [TOP #numbering("1.1.1", ..nums)]
  let time-format = "[hour]:[minute] Uhr"
  let date-format = "[day].[month].[year]"

  // Helpers
  let render-warnings(list: none) = {
    if (hide-warnings) {
      return
    }
    let end-list = list == none
    context {
      let list = if (list != none) {
        list
      } else {
        warnings.get().values()
      }
      if (list.len() < 1) { return }
      align(center)[
        #set par.line(number-clearance: 200pt)
        #if (end-list) [
          #set text(fill: warning-color)
          Warnings:
        ]
        #block(stroke: warning-color, inset: 1em, radius: 1em, fill: warning-color.transparentize(80%))[
          #set align(left)
          #grid(
            row-gutter: 1em,
            ..list.map(x => link(
              x.at(1),
              if (end-list) {
                [Page #str(x.at(1).page())/*, Line #x.at(1).line()*/: ]
              }
                + x.at(0),
            ))
          )
        ]
      ]
    }
  }

  let add-warning(text, id: none, display: false) = [
    #context [
      #let location = here()
      #warnings.update(x => {
        let id = if (id == none) { str(x.len()) } else { id }
        if (not x.keys().contains(id)) {
          x.insert(id, (text, location))
        }
        return x
      })
      #if (display or display-all-warnings) [
        #render-warnings(list: ((text, location),))
      ]
    ]
  ]

  let remove-warning(id) = [
    #warnings.update(x => {
      if (x.contains(id)) {
        _ = x.remove(x.position(x => x == id))
      }
      return x
    })
  ]

  let parse-time(time-string) = {
    if (time-string.contains("+")) {
      let only-time = time-string.split("+")[0]
      let time = datetime(hour: int(only-time.slice(0, 2)), minute: int(only-time.slice(2)), second: 0)
      return time.display(time-format) + super([+#time-string.split("#")[1]])
    } else {
      if (time-string.len() > 2) {
        let time = datetime(hour: int(time-string.slice(0, 2)), minute: int(time-string.slice(2)), second: 0)
        return time.display(time-format)
      } else {
        "????"
      }
    }
  }

  let format-time(time-string, display: true, hours-manual: none) = [
    #context [
      #let time-string = time-string

      #if (display) {
        parse-time(time-string)
      }

      #if (hours-manual == none) {
        last-time.update(time-string)
        if (start-time.get() == none) {
          start-time.update(time-string)
        }
      }
    ]
  ]

  let timed(time, it) = [
    #if (it == "") {
      format-time(time, display: false)
    } else {
      set par.line(number-clearance: 200pt)
      block(
        width: 100%,
        inset: (left: -2cm - timestamp-margin),
      )[
        #grid(
          columns: (2cm, 1fr),
          column-gutter: timestamp-margin,
          align(right)[
            #v(0.05em)
            #text(10pt, weight: "regular")[
              #if (type(time) == content) [
                #time
              ] else [
                #format-time(time)
              ]
            ]
          ],
          it,
        )
      ]
    }
  ]

  let royalty-connectors = (
    "von der",
    "von",
    "de",
  )

  let pretty-name-connect(names, type-id) = {
    if (names.len() == 1) {
      names.at(0)
    } else {
      names.slice(0, -1).join(", ") + " und " + names.at(-1)
    }

  }

  let to-string(it) = {
    if it == none {
      ""
    }
    else if type(it) == str {
      it
    } else if type(it) != content {
      str(it)
    } else if it.has("text") {
      it.text
    } else if it.has("children") {
      it.children.map(to-string).join()
    } else if it.has("body") {
      to-string(it.body)
    } else if it == [ ] {
      " "
    }
  }
  
  let active-votes() = [
    #let take = (arr, n) => arr.slice(0, calc.min(arr.len(), n))    
    #context [
      #let present = pres.get().len() + onl.get().len()
      #let voting = list-votes.pairs().map(pair => (
        pair.first(), 
        take((pres
        .get() + onl.get())
        .filter(e => type(e) == str)
        .filter(person => person.contains("("+pair.first()+")")),
        pair.at(1))
      ))
      (_#voting.fold(0, (p, c) => p + c.at(1).len()) von #present stimmberechtigt_#h(.175em))
    ]
  ]

  let format-name(name) = {
    if (name.starts-with("-")) {
      return "%esc%" + name.slice(1)
    }

    let parts = name.trim().split("_")

    if (parts.len() == 1) {
      let matches = people.filter(person => {
        let person-parts = person.split(" ").filter(e => not e.starts-with("("))
        person-parts.contains(parts.at(0))
      })

      if (matches.len() == 1) {
        return matches.at(0)
      }
      if (matches.len() > 1) {
        return text(fill: orange, weight: "extrabold", name + "[unklar]")
      }
    }

    return text(fill: red, weight: "extrabold", "[unbekannt]")
  }

  let get-status(name) = {
    if (pres.get().contains(name)) {
      return status-present
    } else if (onl.get().contains(name)) {
      return status-online
    } else if (away.get().contains(name)) {
      return status-away
    } else if (away-perm.get().contains(name)) {
      return status-away-perm
    }
    return status-none
  }

  // Inline functions
  let join(time, name, long: false, is-online: false) = [
    #context [
      #let name = format-name(name.trim())

      #let status = get-status(name)
      #if (long) {
        if (status == status-away) {
          add-warning("\"" + name-format(name, "warning") + "\" joined (++), but was just gone for a while (-)")
        } else if (status == status-away-perm) {
          add-warning("\"" + name-format(name, "warning") + "\" joined (++), but already left permanently (--)")
        }

        if (is-online) {
          onl.update(x => {
            if (not x.contains(name)) {
              x.push(name)
            }
            return x
          })
        } else {
          pres.update(x => {
            if (not x.contains(name)) {
              x.push(name)
            }
            return x
          })
        }
      } else {
        if (status == status-away-perm) {
          add-warning("\"" + name-format(name, "warning") + "\" joined (+), but already left permanently (--)")
        } else if (status == status-none) {
          add-warning("\"" + name-format(name, "warning") + "\" joined (+), but is unaccounted for")
        } else if (status != status-away) {
          add-warning("\"" + name-format(name, "warning") + "\" joined (+), but was never away (-)")
        }

        away.update(x => {
          if (x.contains(name)) {
            _ = x.remove(x.position(x => x == name))
          }
          return x
        })
        if (is-online) {
          onl.update(x => {
            if (not x.contains(name)) {
              x.push(name)
            }
            return x
          })
        } else {
          pres.update(x => {
            if (not x.contains(name)) {
              x.push(name)
            }
            return x
          })
        }
      }
    ]
    #context [
      #let name = format-name(name)
      #let total-present = pres.get().len() + onl.get().len()
      #let total-expected = total-present + away.get().len()
      #let statement = [#if (long) [#name meldet sich an] else [#name kehrt wieder] #active-votes()]
      
      #if (time == none) {
        grid(
            columns: (1fr, auto, 1fr),
            align: (horizon, center, horizon),
            column-gutter: 0.5em,
            line(length: 100%, stroke: 0.5pt + gray),
            statement,
            line(length: 100%, stroke: 0.5pt + gray),
          )
      } else {
        timed(time)[
          #grid(
            columns: (1fr, auto, 1fr),
            align: (horizon, center, horizon),
            column-gutter: 0.5em,
            line(length: 100%, stroke: 0.5pt + gray),
            statement,
            line(length: 100%, stroke: 0.5pt + gray),
          )
        ]
      }
    ]
  ]

  let leave(time, name, long: false) = [
    #context [
      #let name = format-name(name)

      #let status = get-status(name)
      #if (long) {
        if (status == status-away-perm) {
          add-warning("\"" + name + "\" left (--), but already left permanently (--)")
        } else if (status == status-none) {
          add-warning("\"" + name + "\" left (--), but is unaccounted for")
        } else if (status != status-present and status != status-online) {
          add-warning("\"" + name + "\" left (--), but was not present (+)")
        }

        away.update(x => {
          if (x.contains(name)) {
            _ = x.remove(x.position(x => x == name))
          }
          return x
        })
        pres.update(x => {
          if (x.contains(name)) {
            _ = x.remove(x.position(x => x == name))
          }
          return x
        })
        onl.update(x => {
          if (x.contains(name)) {
            _ = x.remove(x.position(x => x == name))
          }
          return x
        })
        away-perm.update(x => {
          if (not x.contains(name)) {
            x.push(name)
          }
          return x
        })
      } else {
        if (status == status-away) {
          add-warning("\"" + name-format(name, "warning") + "\" left (-), but was away anyways (-)")
        } else if (status == status-away-perm) {
          add-warning("\"" + name-format(name, "warning") + "\" left (-), but already left permanently (--)")
        } else if (status == status-none) {
          add-warning("\"" + name-format(name, "warning") + "\" left (-), but is unaccounted for")
        } else if (status != status-present and status != status-online) {
          add-warning("\"" + name-format(name, "warning") + "\" left (-), but was not present (+)")
        }

        pres.update(x => {
          if (x.contains(name)) {
            _ = x.remove(x.position(x => x == name))
          }
          return x
        })
        onl.update(x => {
          if (x.contains(name)) {
            _ = x.remove(x.position(x => x == name))
          }
          return x
        })
        away.update(x => {
          if (not x.contains(name)) {
            x.push(name)
          }
          return x
        })
      }
    ]
    #context [
      #let name = format-name(name)
      #let total-present = pres.get().len() + onl.get().len()
      #let total-expected = total-present + away.get().len()
      #let statement = [#if (long) [#name verlässt die Sitzung] else [#name geht vorrübergehend] #active-votes()]

      #if (time == none) {
        grid(
            columns: (1fr, auto, 1fr),
            align: (horizon, center, horizon),
            column-gutter: 0.5em,
            line(length: 100%, stroke: 0.5pt + gray),
            statement,
            line(length: 100%, stroke: 0.5pt + gray),
          )
      } else {
        grid(
            columns: (1fr, auto, 1fr),
            align: (horizon, center, horizon),
            column-gutter: 0.5em,
            line(length: 100%, stroke: 0.5pt + gray),
            timed(time)[
          #statement
        ],
            line(length: 100%, stroke: 0.5pt + gray),
          )
        
      }
    ]
  ]

  let no_online(time, long: false) = [
    #context [
      #let online-list = onl.get()
      
      #for name in online-list {
        let status = get-status(name)
        if (long) {
          if (status == status-away-perm) {
            add-warning("\"" + name-format(name, "warning") + "\" (online) left (--), but already left permanently (--)")
          } else if (status != status-online) {
            add-warning("\"" + name-format(name, "warning") + "\" (online) left (--), but was not online")
          }

          away.update(x => {
            if (x.contains(name)) {
              _ = x.remove(x.position(x => x == name))
            }
            return x
          })
          away-perm.update(x => {
            if (not x.contains(name)) {
              x.push(name)
            }
            return x
          })
        } else {
          if (status == status-away) {
            add-warning("\"" + name-format(name, "warning") + "\" (online) left (-), but was away anyways (-)")
          } else if (status == status-away-perm) {
            add-warning("\"" + name-format(name, "warning") + "\" (online) left (-), but already left permanently (--)")
          } else if (status != status-online) {
            add-warning("\"" + name-format(name, "warning") + "\" (online) left (-), but was not online")
          }

          away.update(x => {
            if (not x.contains(name)) {
              x.push(name)
            }
            return x
          })
        }
      }
      
      onl.update(x => ())
    ]
    #context [
      #let total-present = without-not-voting(pres.get()).len() + without-not-voting(onl.get()).len()
      #let total-expected = total-present + without-not-voting(away.get()).len()
      #let statement = [
        _All online participants #translate("LEAVE" + if (long) { "_LONG" }, str(total-present), str(total-expected))_
      ]

      #if (time == none) {
        statement
      } else {
        timed(time)[
          #statement
        ]
      }
    ]
  ]

  let dec(time, content, args) = [
    #set par.line(number-clearance: 200pt)
    #let values = ()
    #if (args.values().all(x => type(x) == array)) {
      values = args
        .keys()
        .map(x => (
          name: x,
          value: int(args.at(x).at(0)),
          color: args.at(x).at(1),
        ))
    } else {
      values = args
        .keys()
        .map(x => (
          name: x,
          value: int(args.at(x).at(0)),
        ))
    }
    #v(2em, weak: true)
    #let dec-block = block(breakable: false, inset: (left: if (indent-decisions) { 2em } else { 0pt }))[
      ===== #content
      #v(-0.5em)
      #let total = values.map(x => x.value).sum(default: 1)

      #if (fancy-decisions and values.at(0).keys().contains("color")) [
        #grid(
          gutter: 2pt,
          columns: values.map(x => calc.max(if (x.value > 0) { 0.2fr } else { 0fr }, 1fr * (x.value / total))),
          ..values.map(x => grid.cell(
            fill: x.color.transparentize(80%),
            inset: 0.5em,
          )[
            #if (x.value > 0) [*#x.name* #x.value]
          ]),
        )
      ] else [
        #values.map(x => [*#x.name*: #str(x.value)]).join([, ])
      ]
      #context [
        #let total-present = pres.get().len() + onl.get().len()
        
        //!FIXME: Counting
        // #if (total != total-present) {
        //   add-warning(
        //     str(total) + " people voted, but " + str(total-present) + " were present",
        //     display: true,
        //   )
        // }
      ]
    ]
    #if (time != none) [#timed(time, dec-block)] else [#dec-block]
  ]

  let end(time) = [
    #set par.line(number-clearance: 200pt)
    #linebreak()
    #if (time == none) [==== Ende der Sitzung] else {
      timed(time)[==== Ende der Sitzung]
      last-time.update(time)
    }
  ]

  // Regex
  let non-name-characters = " .:;?!"
  let regex-time-format = "[0-9]{1,4}"
  let regex-name-format = (
    "-?("
      + royalty-connectors.join(" |")
      + " )?(\p{Lu})[^"
      + non-name-characters
      + "]*( "
      + royalty-connectors.join("| ")
      + ")?( (\p{Lu}|[0-9]+)[^"
      + non-name-characters
      + "]*)*"
  )
  let default-format = regex-time-format + "/[^\n]*"
  let optional-time-format = "(" + regex-time-format + "/)?[^\n]*"

  let default-regex(keyword, function, body, time-optional: false) = [
    #show regex(
      "^" + keyword.replace("+", "\+") + if (time-optional) { optional-time-format } else { default-format },
    ): it => [
      #let text = it.text.slice(keyword.len())
      #let time = text.split("/").at(0)
      #let string = text.split("/").slice(1).join("/")

      #if (time-optional and time.match(regex("^" + regex-time-format + "$")) == none) {
        string = time
        time = none
      }

      #function(time, string)
    ]

    #body
  ]

  show: default-regex.with("+", join, time-optional: true)
  show: default-regex.with("-", leave, time-optional: true)
  show: default-regex.with("−", leave, time-optional: true)
  show: default-regex.with("++", join.with(long: true), time-optional: true)
  show: default-regex.with("–", leave.with(long: true), time-optional: true)
  show: default-regex.with("", timed)

  // Add new regex for online joins
  show regex("^\+o(" + optional-time-format + ")"): it => {
    let text = it.text.slice(2)
    let time = text.split("/").at(0)
    let string = text.split("/").slice(1).join("/")

    if (time.match(regex("^" + regex-time-format + "$")) == none) {
      string = time
      time = none
    }

    join(time, string, is-online: true)
  }

  show regex("^\+\+o(" + optional-time-format + ")"): it => {
    let text = it.text.slice(3)
    let time = text.split("/").at(0)
    let string = text.split("/").slice(1).join("/")

    if (time.match(regex("^" + regex-time-format + "$")) == none) {
      string = time
      time = none
    }

    join(time, string, long: true, is-online: true)
  }

  show regex("^(" + regex-time-format + "/)no_online\(long: (true|false)\)"): it => {
    let time = it.text.split("/").at(0)
    let is-long = it.text.contains("true")
    no_online(time, long: is-long)
  }

  show regex("^/(" + regex-time-format + "|end)"): it => {
    let time = it.text.slice(1)
    if (time == "end") {
      context {
        end(last-time.get())
      }
    } else {
      end(time)
    }
  }

  show regex("^!(" + regex-time-format + "/)?.*[^-]/(.*(|.*)?[0-9]+){2,}"): it => [
    #let text = it.text.replace("-/", "%slash%").slice(1)
    #let time = text.split("/").at(0)

    #let args-slice = 2

    #if (time.match(regex("^" + regex-time-format + "$")) == none) {
      time = none
      args-slice = 1
    }

    #let args = (
      text
        .split("/")
        .slice(args-slice)
        .enumerate()
        .fold(
          (:),
          (args, x) => {
            let label = x.at(1).replace(regex("[0-9]"), "")
            let value = x.at(1).replace(label, "")

            if (label != "" and label.at(-1) == " ") {
              label = label.slice(0, -1)
            }

            let color-string = none
            if (label.contains("|")) {
              color-string = label.split("|").at(1)
              label = label.replace("|" + color-string, "")
            }

            if (label == "") {
              label = str(x.at(0) + 1)
            }

            label = label.replace("%slash%", "/")
            if (color-string != none) {
              args.insert(label, (value, eval(color-string)))
            } else {
              args.insert(label, value)
            }

            return args
          },
        )
    )

    #let text = text.split("/").at(args-slice - 1).replace("%slash%", "/")

    #if (
      args.len() == 3
        and args.keys().enumerate().all(x => str(x.at(0) + 1) == x.at(1))
        and args.values().all(x => type(x) != array)
    ) {
      let yes = args.values().at(0)
      let no = args.values().at(1)
      let abst = args.values().at(2)
      dec(time, text, ("Dafür": (yes, green), "Dagegen": (no, red), "Enthaltung": (abst, blue)))
    } else {
      dec(time, text, args)
    }
  ]

  show regex("(.)?/" + regex-name-format): it => {
    context {
      let text = if (it.text.starts-with("\u{200b}")) {
        it.text.slice(3)
      } else {
        it.text
      }
      if (not (text.at(0) == "/" or text.slice(0, 2) == " /")) {
        it
        return
      }

      let name = text.slice(if (text.at(0) == "/") { 1 } else { 2 })

      name = format-name(name)

      if (text.at(0) != "/") {
        text.at(0)
      }
      name

      let status = get-status(name)
      if (status == status-away) {
        add-warning("\"" + name, "warning" + "\" was mentioned, but was away (-)")
      } else if (status == status-away-perm) {
        add-warning("\"" + name + "\" was mentioned, but left (--)")
      } else if (status == status-none) {
        add-warning("\"" + name + "\" was mentioned, but is unaccounted for")
      }
    }
  }

  // Setup
  set page(
    header: {
      let formatted-date = if (type(date) == datetime) {
        [#date.display(date-format)]
      } else { [#date] }

      [#body-name] 

      [ #event-name]

      grid(
        columns: if (logo != none) { (auto, 1fr) } else { 1fr },
        align: horizon,
        gutter: 1em,
        if (logo != none) {
          set image(
            height: 3em,
            fit: "contain",
          )
          logo
        },
        [
          #formatted-date\
          #body-name: #event-name\
        ]
      )
  
    },
    footer: context {
      let current-page = here().page()
      let page-count = (
        counter(page).final().first() - if (warnings.final().len() > 0 and not hide-warnings) { 1 } else { 0 }
      )
      align(center, [Seite #current-page von #page-count])
    },
    margin: (
      left: 4cm,
      right: 2cm,
      top: 3cm,
      bottom: 6cm,
    ),
    background: if (hole-mark) {
      place(
        left + top,
        dx: 5mm,
        dy: 100% / 2,
        line(
          length: 4mm,
          stroke: 0.25pt + black,
        ),
      )
    }
    
  )

  set text(
    10pt,
    lang: "de",
  )

  set par(justify: true)

  set heading(
    outlined: false,
    numbering: (..nums) => {
      nums = nums.pos()
      nums = nums.map(x => int(x / 2))
      item-numbering(..nums)
    },
  )
  show heading: set text(12pt)
  show heading: it => {
    let text = if (it.body.has("children")) {
      it.body.children.map(i => if (i.has("text")) { i.text } else { " " }).join()
    } else {
      it.body.text
    }

    if (text.starts-with("\u{200B}")) {
      [#it]
      return
    }

    let (time, title) = if (text.match(regex(regex-time-format + "/")) != none) {
      (text.split("/").at(0), text.split("/").slice(1).join("/"))
    } else {
      (none, text)
    }
    title = heading(
      "\u{200B}" + title,
      level: it.level,
      outlined: it.level != 4 and text != "Tagesordnung",
      numbering: if (it.level >= 4) { none } else { it.numbering },
    )

    let heading = if (time == none) {
      title
    } else {
      timed(time, title)
    }
    [
      #if (separator-lines and (it.level == 1 or it.level == 4)) {
        grid(
          columns: (auto, 1fr),
          align: horizon,
          gutter: 1em,
          heading, line(length: 100%, stroke: 0.2pt),
        )
      } else {
        heading
      }
      #v(0.5em)
    ]
  }

  // Protokollkopf

  // Validate that present and online are subsets of people
  let old-present = present
  
  for person in present {
    if (not people.contains(person)) {
      add-warning("\"" + person + "\" is in present list but not in people list")
    }
  }
  
  for person in online {
    if (not people.contains(person)) {
      add-warning("\"" + person + "\" is in online list but not in people list")
    }
  }

  if (awareness != none) {
    if (type(awareness) == str) {
      awareness = format-name-no-context(awareness)
      if (not present.contains(awareness)) {
        present.insert(0, awareness)
      }
    } else {
      for person in awareness {
        person = format-name-no-context(person)
        if (not present.contains(person)) {
          present.insert(0, person)
        }
      }
    }
  }
  if (secretary != none) {
    if (type(secretary) == str) {
      if (not present.contains(secretary)) {
        present.insert(0, secretary)
      }
    } else {
      for person in secretary {
        if (not present.contains(person)) {
          present.insert(0, person)
        }
      }
    }
  }
  if (chairperson != none) {
    if (type(chairperson) == str) {
      if (not present.contains(chairperson)) {
        present.insert(0, chairperson)
      }
    } else {
      for person in chairperson {
        if (not present.contains(person)) {
          present.insert(0, person)
        }
      }
    }
  }

  let formatted-chairperson = if (chairperson == none) [
    #custom-name-style("MISSING", "header")
    #add-warning("chairperson is missing")
  ] else if (type(chairperson) == str) {
    [#name-format(format-name-no-context(chairperson), "header")]
  } else {
    [#pretty-name-connect(chairperson, "header")]
  }

  let formatted-secretary = if (secretary == none) [
    #custom-name-style("MISSING", "header")
    #add-warning("secretary is missing")
  ] else if (type(secretary) == str) {
    [#name-format(format-name-no-context(secretary), "header")]
  } else {
    [#pretty-name-connect(secretary, "header")]
  }

  let formatted-awareness = if (awareness == none) {
    none
  } else {
    if (type(awareness) == str) {
      [#name-format(format-name-no-context(awareness), "header")]
    } else {
      [#pretty-name-connect(awareness, "header")]
    }
  }

  let formatted-present = [
    #let body-string = (
      body
        .children
        .map(i => {
          let body = if (i.has("body")) { i.body } else { i }

          return if (body.has("text")) { body.text } else { "" }
        })
        .join("\n")
    )
    #if (body-string == none) {
      body-string = ""
    }

    #let join-long-regex = "\n++" + optional-time-format
    #let join-online-long-regex = "\n\\+\\+o" + optional-time-format

    #let matches = body-string.matches(regex(join-long-regex.replace("+", "\+")))
    #let online-matches = body-string.matches(regex(join-online-long-regex))
    #let time-matches = body-string.matches(regex(regex-time-format + "/")).filter(x => x.text.len() >= 4)

    #context [
      #let arrives-later = (:)
      #let arrives-later-online = (:)
      
      #for match in matches {
        let split = match.text.split("/")

        if (split.len() == 1) {
          let time = none
          let name = format-name(split.at(0).slice(3))
          arrives-later.insert(name, time)
        } else {
          let time = split.at(0).slice(3)
          let hours = ""
          if (time.len() > 2) {
            hours = time.slice(0, 2)
          } else {
            let last-time = time-matches.filter(x => x.end < match.start).last().text.slice(0, -1)

            hours = last-time.slice(0, 2)
          }
          let time = format-time(split.at(0).slice(3), hours-manual: hours)

          let name = format-name(split.at(1))
          arrives-later.insert(name, time)
        }
      }

      #for match in online-matches {
        let split = match.text.split("/")

        if (split.len() == 1) {
          let time = none
          let name = format-name(split.at(0).slice(4))
          arrives-later-online.insert(name, time)
        } else {
          let time = split.at(0).slice(4)
          let hours = ""
          if (time.len() > 2) {
            hours = time.slice(0, 2)
          } else {
            let last-time = time-matches.filter(x => x.end < match.start).last().text.slice(0, -1)

            hours = last-time.slice(0, 2)
          }
          let time = format-time(split.at(0).slice(4), hours-manual: hours)

          let name = format-name(split.at(1))
          arrives-later-online.insert(name, time)
        }
      }

      #let present = present + arrives-later.keys().filter(x => not present.contains(x)) + arrives-later-online.keys().filter(x => not present.contains(x))
      #all.update(present)
      #let filtered = present.filter(x => not arrives-later.keys().contains(x) and not arrives-later-online.keys().contains(x))
      #pres.update(filtered.filter(x => not online.contains(x)))
      #onl.update(online)
      
      #grid(
        columns: calc.min(2, calc.ceil(present.len() / 10)) * (1fr,),
        row-gutter: 0.65em,
        ..present.map(x => {
          x
          if (online.contains(x)) {
            [ (online)]
          }
          if (show-arrival-time and arrives-later.keys().contains(x)) {
            if (arrives-later.at(x) == none) {
              [ (#translate("DURING_EVENT"))]
            } else {
              [ (#translate("SINCE") #box[#arrives-later.at(x)])]
            }
          }
          if (show-arrival-time and arrives-later-online.keys().contains(x)) {
            if (arrives-later-online.at(x) == none) {
              [ (online, #translate("DURING_EVENT"))]
            } else {
              [ (online, #translate("SINCE") #box[#arrives-later-online.at(x)])]
            }
          }
        })
      )
    ]

  ]

  let formatted-present-count = if (number-present) {
    present.len()
  } else {
    none
  }

    [
      #if location != none [*Ort*: #location\ ]
      *Sitzungsleitung*: #formatted-chairperson\
      *Protokoll*: #formatted-secretary\
      #if formatted-awareness != none [*Awareness*: #formatted-awareness\ ]

      *Anwesend*:
      #v(-0.5em)

      #pad(left: 1em)[
        #formatted-present
      ]

      #context {
        let start-time = start-time.final()
        if (start-time != none) [*Beginn der Sitzung*: #format-time(start-time)\ ]

        let end-time = last-time.final()
        if (end-time != none) [*Ende der Sitzung*: #format-time(end-time)]
      }
    ]

    if(long-toc) {
      pagebreak()
    } 
    
    pad(y: 1.5em)[
      #show outline.entry.where(level: 1): it => {
        v(0em)
        it
      }
      #outline(title: "Tagesordnung", indent: 1em, depth: 4)
    ]

  pagebreak()

  context {
    let start-time = start-time.final()
    if (start-time == none) {
      timed([], [==== Beginn der Sitzung])
    } else {
      timed([#parse-time(start-time)], [==== Beginn der Sitzung])
    }
  }

  set par.line(
    numbering: x => {
      if (
        line-numbering != none and calc.rem(x, line-numbering) == 0
      ) { text(size: 0.8em)[#x] }
    },
    number-clearance: timestamp-margin,
    numbering-scope: "page",
  )

  // Hauptteil
  {
    show regex("-:"): it => {
      [:]
    }

    body
  }

  // Schluss
  set par.line(number-clearance: 200pt)
  context {
    let count-away = away.get().len()
  }

  if (signing) {
    block(breakable: false)[
      #v(3cm)
      #translate("SIGNATURE_PRE"):

      #v(1cm)
      #grid(
        columns: (1fr, 1fr, 1fr),
        align: center,
        gutter: 0.65em,
        line(length: 100%, stroke: 0.5pt), line(length: 100%, stroke: 0.5pt), line(length: 100%, stroke: 0.5pt),
        [#translate("PLACE_DATE")],
        [#translate("SIGNATURE") #if (cosigner == none) [#translate("CHAIR")] else [#cosigner]],
        [#translate("SIGNATURE") #translate("PROTOCOL")],

        [],
        if (cosigner == none) {
          if (chairperson == none) {
            name-format("MISSING", "signature")
          } else if (type(chairperson) == str) {
            name-format(chairperson, "signature")
          } else {
            chairperson.map(x => name-format(x, "signature")).join("\n")
          }
        } else {
          name-format(
            if (cosigner-name == none) {
              "MISSING"
              add-warning("cosigner-name is missing")
            } else {
              cosigner-name
            },
            "signature",
          )
        },
        if (secretary == none) {
          name-format("MISSING", "signature")
        } else if (type(secretary) == str) {
          name-format(secretary, "signature")
        } else {
          secretary.map(x => name-format(x, "signature")).join("\n")
        },
      )
    ]
  }

  // Hinweise
  context {
    if (warnings.get().len() > 0) {
      set page(header: none, footer: none, margin: 2cm, numbering: none)
      render-warnings()
    }
  }
}
