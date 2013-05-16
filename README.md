LuaTeX-ko Package version 1.0 (2013/05/10)
==========================================

This is a Lua(La)TeX macro package that supports typesetting Korean
documents including Old Hangul texts. As LuaTeX has opened up access to
almost all the hidden routines of TeX engine, users can obtain more
beautiful outcome using this package rather than other Hangul macros
operating on other engines. 

Due to the backward-incompatible update of LuaTeX in early 2013, LuaTeX
version 0.76+ and luaotfload package version 2.2+ are required for this
package to run. 

This package also requires both cjk-ko and xetexko packages for its full
functionality.


License
-------

This package is licensed under [LPPL](http://latex-project.org/lppl/)
(LaTeX Project Public License) version 1.3c or later.

See each file for details.


Author
------

Please report any errors or suggestions to Dohyun Kim ``<nomos at ktug org>``.


Files
-----

- TeXinputs

		luatexko.sty		-> tex/luatex/luatexko/
		luatexko-core.sty	-> tex/luatex/luatexko/
		luatexko.lua		-> tex/luatex/luatexko/
		luatexko-normalize.lua	-> tex/luatex/luatexko/
		luatexko-uhc2utf8.lua	-> tex/luatex/luatexko/

- Documents

		luatexko-doc.pdf	-> doc/luatex/luatexko/
		luatexko-doc.tex	-> doc/luatex/luatexko/
		README (this file)	-> doc/luatex/luatexko/


Loading
-------

For a LaTeX user, declaring

		\usepackage{luatexko}
or

		\usepackage{kotex}
is sufficient to load the package, which will load fontspec as well.
Notice that kotex.sty is a file provided by cjk-ko package.

Under plain TeX:

		\input luatexko.sty 


Package Options
---------------

* ``[hangul]``

    Load Hangul captions. Besides, this option adjusts interword and
    interline spacing.

* ``[hanja]``

    Load Hanja captions. Also adjusts spacing as [hangul] option does.

* ``[unfonts]``

    Load font setting predefined for Un TrueType fonts available at
    [this link](http://kldp.net/projects/unfonts/).


Hangul Font Commands
--------------------

		\setmainhangulfont
		\setsanshangulfont
		\setmonohangulfont
Equivalent to \setmainfont et. al. of fontspec package. These fonts are
used when the font loaded by \setmainfont et. al. does not have Hangul
glyphs.

		\setmainhanjafont
		\setsanshanjafont
		\setmonohanjafont
These fonts are used when the font loaded by \setmainfont or
\setmainhangulfont et. al. does not have Hanja glyphs.

In like manner, these commands are available as well:

		\hangulfontspec
		\hanjafontspec
		\newhangulfontfamily
		\newhanjafontfamily
		\addhangulfontfeature
		\addhanjafontfeature


Hangul Font Options
-------------------

* ``[InterHangul=<dimen>]``

    Set spacing between Hangul characters.

* ``[InterLatinCJK=<dimen>]``

    Set spacing between CJK and Latin characters.

* ``[PunctRaise=<dimen>]``

    Raise Latin fullstop and comma after CJK character.

* ``[QuoteRaise=<dimen>]``

    Raise Latin quotation marks and parentheses around CJK text.

* ``[CharRaise=<dimen>]``

    Raise CJK characters by ``<dimen>``.


Other User Commands
-------------------

		\luatexuhcinputencoding=<number>
When ``<number>`` is 1 or greater, UHC (aka. Windows CP949) input encoding
is allowed. ``<number>`` 0 restores UTF-8, the default input encoding.

		\dotemph{...}
Emphasise Hangul or Hanja by putting dot above.

		\ruby{<base text>}{<ruby text>}
Typeset ruby annotations.

		\uline{...}
		\sout{...}
		\uuline{...}
		\xout{...}
		\uwave{...}
		\dashuline{...}
		\dotuline{...}
Same functionality as ulem package provides.

*END of README*
