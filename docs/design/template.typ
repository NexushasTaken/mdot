// Shared styling for mdot documents.

#let base(title: "", body) = {
  set document(title: title)
  set page(paper: "a4", margin: (x: 2.2cm, y: 2.4cm), numbering: "1")
  set text(size: 10.5pt)
  set par(justify: true)
  set heading(numbering: "1.1")
  show heading.where(level: 1): set block(above: 1.6em, below: 0.9em)
  show link: set text(fill: rgb("#1a5fb4"))
  show raw.where(block: true): block.with(
    fill: luma(245), inset: 8pt, radius: 3pt, width: 100%,
  )
  set table(stroke: 0.5pt + luma(170), inset: 6pt)
  show table.cell.where(y: 0): strong
  show table: set par(justify: false)
  body
}

#let titleblock(title, subtitle: none, meta: none) = {
  align(center)[
    #set par(justify: false)
    #set text(hyphenate: false)
    #text(size: 20pt, weight: "bold", title)
    #if subtitle != none [ \ #text(size: 13pt, subtitle) ]
    #if meta != none [ \ #v(0.3em) #text(size: 9.5pt, fill: luma(90), meta) ]
  ]
  v(1.2em)
}

// Research paper: title, abstract, numbered sections.
#let paper(title: "", subtitle: none, meta: none, abstract: none, body) = base(title: title)[
  #titleblock(title, subtitle: subtitle, meta: meta)
  #if abstract != none {
    pad(x: 1.5cm)[
      #align(center, text(weight: "bold")[Abstract])
      #set text(size: 9.5pt)
      #abstract
    ]
    v(1em)
  }
  #body
]

// Spec document.
#let spec(title: "", meta: none, body) = base(title: title)[
  #titleblock(title, meta: meta)
  #body
]

// Switch heading numbering to appendix style (A, A.1, ...).
#let appendix(body) = {
  counter(heading).update(0)
  set heading(numbering: "A.1", supplement: [Appendix])
  body
}

// One architecture decision record, meant to be #include'd by adr/main.typ.
#let pad4(n) = { let s = str(n); "0" * (4 - s.len()) + s }

#let adr(number: 0, title: "", status: "", date: "", body) = {
  pagebreak(weak: true)
  [#heading(level: 1, numbering: none)[ADR-#pad4(number): #title] #label("adr-" + pad4(number))]
  grid(
    columns: 2, column-gutter: 1em, row-gutter: 0.5em,
    text(weight: "bold")[Status], status,
    text(weight: "bold")[Date], date,
  )
  set heading(numbering: none, offset: 1)
  body
}
