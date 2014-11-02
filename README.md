This is some code I wrote for a very short term contract in Los Angeles. It's worth looking at because it shows I can write trivial OSX apps again after not having done so for a long time. And that I can read the sqlite3 man page and start using SQL in at a pretty basic level in one day. Also that I care about software engineering and I put some common code into a library (framework) called MFLib. That's where any interesting code is, if there is any.

In fact making an OSX framework for the first time was my big triumph at that gig. The documentation on how to do that isn't that good and you have to do some relocatable symbol setting in Xcode that I've already forgotten.

There's some reasonably non-trivial code (MFLib/MFWebPage.[hm]) that executes javascript to be able to scrape modern web pages, which can't be interpreted in HTML alone. 

There's some code MFLib/MFLib/MFDB* that shows how I recoil from litering high level code with direct calls to some database library: the MFDB classes abstract all that away.

Like an idiot I tried to write some scrapers that were based on treating a web page as its DOM tree, but that simply didn't work nearly as well as just scraping lexigraphically or flat-token-wise or whatever you call it. I would have done some actual research on this had the contract lasted longer. If there's ever an example of where the term "Best Practices" actually has meaning, this would be it.


