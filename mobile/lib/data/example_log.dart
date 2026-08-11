// A real, hand-written training log, bundled as the "⭐ Beispielplan laden"
// preset so anyone can try the app with realistic data right away, and,
// critically, as `log_parser.dart`'s primary regression-test fixture.
const String exampleLog = '''1PR(27.04.2026)
Deadlift 150kg
Klimmzüge 40kg
Benchpress 87.5kg
Overheadpress 60kg
Kabelseitheben 7.5kg 8
Squat 120kg


Cat and Cow 1x8
1x ✓

Ausfallschritt 1x8
1x ✓

Ausfallschritt Rotationen (Knie vom Boden und Arm vom Boden nach oben ausgestreckt) 1x8
1x ✓

Bein ausgestreckt und anderes vorne, ca. 30° 1x8
1x ✓

Ausfallschritt auf dem Bett 1x8
1x ✓

Boden Ficker 1x8
1x ✓

Liegend Bein zur anderen Seite legen 1x8
1x ✓

Schneidersitz anbetten 1x8
1x ✓

Waage 1x8
1x ✓

Liegend diagonal Hand und Fuß berühren 1x8
1x ✓

Vierfüßlerstand, abwechselnd die Hand heben 1x8
1x ✓


Unterrücken (Unterrücken als erstes gerade)
10kg x2 10.7 12.8
15kg x1 7.6
20kg x4 6.4 8.7 8.7 9.5
22kg x1 7.5


1.Wochentag
Deadlift 2x3
120kg x1 3.3
122.5kg x1 3.3
125kg x1 3.3
127.5kg x1 3.3
130kg x1 3.3
132.5kg x1 3.3
135kg x5 2.1 1.1 2.2 1.0 3.2
137.5kg x1 3.3
140kg x2 3.2 3.2
130kg x1 6.4
135kg x1 3.2
115kg x1 10.8
120kg x4 8.4 10.5 5.5
125kg x5 5.3 0.0 0.0 3.2 3.m
130kg x2 2.1 3.2
132.5kg x1 3.2
135kg x1 3.2
137.5kg x2 2.1 2.m
110kg

Klimmzüge 2x6-10
18.75kg x4 7.5 8.6 9.6 10.7
20kg x6 8.6 8.7 7.6 6.4 8.6 10.7
21.25kg x2 6.6 9.7
22.5kg x6 6.5 7.5 6.4 8.6 9.7
25kg x8 6.5 7.6 8.5 8.5 7.6 8.4 4.3 5.3
15kg x1 14.8
17.5kg x2 7.4 10.7
20kg x2 7.5 9.12
22.5kg x1 7.5

Langhantelrudern 2x6-10
Ein-armige Rows
40kg x1 10.10.10
70kg x3 8.7.6 9.7.7 10.8.8
72.5kg x2 7.6 9.7
75kg x2 7.6 10.9
78.5kg x2 8.6 11.8
80kg x3 6.5 7.4 10.8
82.5kg x3 6.5 8.7 10.7
85kg x6 6.4 7.5 7.4 5.4 7.5 0.0
80kg x1 9.7
65kg x1 5.4
Ein-armige Rows
42kg x1 10.8
44kg x1 11.6
46kg x1 12.15
48kg x1 9.5
50kg x3 8.6 8.5 10.6
Langhantel
70kg x

Breites rudern 2x6-10
50kg x2 9.8 10.10
55kg x4 6.5 9.8 10.10 10.10
60kg x5 6.5 7.4 8.6 10.7 10.8
65kg x7 7.6 7.5 8.6 9.7 10.6 10.8 10.5
70kg x5 6.4 7.6 7.5 0.0
45kg x1 7.6
20kg x1 7.6
35kg x2 8.5 10.12
40kg x2 7.5 10.7
45kg x3 7.5 7.6 8.7

Zstange Biceps curls 2x6-10
40kg x4 6.4 7.6 8.6 9.7
42.5kg x3 7.6 8.7 5.4
40kg x5 6.4 7.5 8.5 9.6 7.5
42.5kg x11 6.5 6.6 7.5 8.5 x.x 8.5 9.6 7.5 8.5 5.3 5.4
30kg x4 5.4 7.6 9.7 10.12
32.5kg x3 7.5 8.6 9.7
35kg x1 5.4


2. Wochentag
Bankdrücken 2x10
72.5kg x1 5.4
70kg x2 7.6 8.5
72.5kg x4 7.4 8.4 5.4 4.4
70kg x1 5.4
75kg x6 4.3 4.2 x.x 4.3 3.2 5.4
77.5kg x7 3.2 3.2 3.3 4.3 4.3 4.4 3.2
80kg x2 3.2 2.1
65kg x2 9.6 12.8
70kg x3 7.5 8.6 9.12
72.5kg x3 6.5 8.4 8.8

Schrägbank 2x6-10
28kg x3 7.6 9.7 10.6
30kg x12 7.3 7.6 8.7 8.5 6.4 9.7 5.5 7.5 6.5 8.6 9.6
32kg x8 6.4 5.5 6.4 6.5 3.5 5.5 6.4 6.6
26kg x1 9.7
28kg x2 8.6 9.12
30kg x5 6.4 7.4 8.7 9.6 6.5

Overhead Press 2x6
40kg x2 8.7 10.8
45kg x2 3.3 6.4
47.5kg x10 3.2 4.2 2.2 3.3 4.2 4.3 2.1 2.3 4.3 5.4
50kg x9 3.2 3.2 3.3 4.3 5.3 3.3 2.1 0.0 3.3
40kg x1 7.3
42.5kg x1 5.6
50kg x2 2.1 3.2
45kg x2 7.3 6.5
47.5kg x1 4.6
50kg x1 4.3

Trizeps Extensions 2x12
35kg x1 12.11
37.5kg x8 8.7 8.7 10.8 12.9 12.9 9.8 10.9 12.8

Ein-armiges Pushdown 2x8-12
9.1kg x2 9.7 10.8
11.3kg x3 7.4 8.5 10.8
13.6kg x3 7.6 8.4 10.7
15.9kg x6 5.4 5.4 7.6 4.4 5.4 6.4
30kg x1 11.8
32.5kg x2 9.7 12.13
35kg x3 8.5 9.6 10.11
37.5kg x2 8.6 9.7

Seitheben Maschine(14) 4x12
12kg x1 12.12.12.10
14kg x12 8.7.6.5 9.8.7.6 12.9.8.7 12.12.9.8 12.12.9.9 8.7.6.5 9.8.6.5 11.10.9.8 12.12.8.8 8.8.8.8 9.8.7.6 11.9.8.7
16kg x7 8.7.6.5 9.8.7.6 9.7.6.5 8.6.5.4 8.7.6.5 7.8.6.5 6.7.5.5
35kg x2 8.7.6.5 5.5.5.5
25kg x1 8.9.8.7
5kg x2 12.7 12.12.9.8
7.5kg x1 4.2.2.2
5kg x3 11.6.5.4 12.8.6.5 12.7.8.6
Seitheben Sitzend
14 x2 12.9.8.7 14.11.9.8


3. Wochentag
Squats 2x4-6
100kg x2 6.4 6.6
102.5kg x2 4.3 6.5
105kg x3 4.3 4.3 5.3
107.5kg x4 4.2 3.2 5.3 6.2
110kg x4 3.2 4.3 5.4 6.4
112.5kg x3 3.1 5.3 6.3
115kg x5 4.3 5.3 0.0 2.1 3.2
110kg x3 3.2 4.3 6.4
112.5kg x3 4.2 5.2 6.7
115kg x1 3.2

Rumänisches Deadlift (Rücken und Beine gerade) 2x6-10
110kg x2 10.10 10.10
112.5kg x2 8.7 10.7
115kg x2 8.7 10.8
117.5kg x3 5.4 7.6 9.7
120kg x1 9.7
122.5kg x4 7.5 7.6 8.6 10.7
125kg x3 7.4 8.2 10.4
127.5kg x6 6.5 7.4 8.5 0.0 6.4 4.3
80kg x3 5.5 10.10 10.10
90kg x1 10.10
92.5kg x1 x.10
95kg x1 10.10
100kg x1 10.6

Hipthrust 2x6-10
160kg x2 8.7 10.8
170kg x3 8.7 10.8 11.9
180kg x5 9.5 5.3 7.6 8.5 9.4
190kg x6 6.5 3.2 6.4 7.4 9.7 9.5
200kg x11 7.5 7.5 5.4 8.6 0.0 6.5 6.4 6.4 7.6 5.4 10.7
Hip Thrust Maschine
90kg x1 8.6
85kg x1 10.7
87.5kg x1 8.7

Adduktor 1xmax
70kg x30 12 x 15 15 16 19 15 16 18 19 20 19 21 15 18 21 16 20 20 0 21 21 15 10 12 14 13 12 16 16

Abduktor 1xmax
55kg x3 8 10 12
60kg x1 10
65kg x1 11
70kg x24 9 11 12 14 14 15 0 8 12 15 15 16 16 14 13 13 15 10 10 11 5 11 12 12

Leg curl 2x6-10
50kg x2 8.7 10.9
52kg x1 9.8
55kg x2 8.7 10.8
57kg x3 6.6 8.7 9.7
59kg x2 7.5 9.7
62kg x4 6.4 7.5 8.5 9.6
64kg x9 6.5 6.5 x.x 7.4 7.5 7.6 8.5 7.4 9.7
45kg x2 9.6 10.12
47.5kg x2 6.4 8.5
50kg x3 5.4 7.5 7.5
52.5kg x

Leg extensions 2x6-10
90kg x1 9.5
92.5kg x1 10.7
95kg x3 7.6 8.7 10.6
97.5kg x4 9.8 0.0 8.7 10.7
100kg x3 6.5 9.7 9.9
102.5kg x3 7.6 8.6 9.5
105kg x8 6.5 x.x x.x 6.5 x.x 7.6 8.6 x.x
65kg x2 10.7 10.8
70kg x1 10.11
75kg x2 7.6 11.7
80kg x1 10.8
90kg x1 10.6


4. Wochentag
Bauch zur Wand 4x20-30sec
1x 20.19.15.10

Kick-ups 5x4-5
1x .....

Planche Leans 3x8-12sec
1x 10.10.9

Tuck Planche 3x6-8sec
1x 4.4.4

Pseudoplanche Push-ups 3x6-10
1x 4.3.2

Tuck Front Lever Hold 3x8-10sec
1x 12.11.10

Negativ Front Lever 3x10
1x 5.4.3


5. Wochentag
Deadlift 2x2-3
125kg x2 4.2 4.3
127.5kg x2 2.1 4.4
130kg x3 3.2 4.3 0.0
132.5kg x2 2.1 3.2
135kg x2 3.2 4.3
137.5kg x1 3.2
140kg x2 3.2 3.4
130kg(hüfte nach hinten) x1 x.x
115kg(bis Ausführung basst) x1 10.7
120kg x3 6.5 8.6 5.4
125kg x6 5.3 5.5 0.0 0.0 1.1 3.3
127.5kg x1 3.2
130kg x1 3.2
132.5kg x1 3.2
135kg x2 1.1 3.2

Klimmzuge 2x4-6
18.75kg x1 7.6
20kg x3 5.4 6.5 7.5
21.25kg x1 6.5
22.5kg x2 4.3 6.5
23.75kg x2 5.4 7.6
25kg x2 5.4 6.4
26.25kg x2 5.3 6.3
27.5kg x3 5.3 4.2 5.4
28.75kg x3 4.3 5.4 6.3
30kg x4 5.3 5.4 6.3 0.0
25kg x1 5.3
15kg x1 8.6
17.5kg x1 7.8
20kg x1 8.6
22.5kg x1 6.4
25kg x1 6.4
27.5kg x1 4.3

Wadenheben (Beinpresse) 2x8-12
150kg x1 12.12
160kg x2 9.8 12.9
170kg x2 9.8 12.9
180kg x2 12.7 0.0
190kg x2 9.7 12.10
200kg x2 9.7 12.8
210kg x3 0.0 9.7 12.9
220kg x2 9.7 12.8
230kg x2 9.6 12.7
240kg x3 8.7 10.8 12.9
250kg x2 9.7 0.0

Hack Squat
70kg x1 12.12
90kg x1 12.12
100kg x1 12.12
110kg x1 12.7
120kg x2 10.7 12.7
130kg x1 8.6

Langhantelrudern (einarmiges Rudern) 2x6-10
70kg x3 7.6 8.7 10.6
72.5kg x2 7.6 9.8
75kg x3 8.7 8.8 10.8
77.5kg x1 8.7
80kg x2 7.6 9.7
82.5kg x4 6.5 7.5 9.5 10.8
85kg x5 6.5 6.5 7.5 6.6 7.6
80kg x3 5.4 6.3 0.0
40kg x1 10.12
44kg x2 7.5 10.6
46kg x1 13.14
48kg x1 10.11
50kg x2 10.6 11.7

Bankdrücken (Schulter breit) 1x2-3
75kg x1 3
77.5kg x1 3
80kg x6 1 2 2 2 1 4
82.5kg x3 1,5 2 0
80kg x1 1
85kg x2 1 1
87.5kg x1 0
80kg x1 3
87.5kg x2 1 1
80kg x4 1 2 2 0
75kg x2 1 3
80kg x3 1 2 2
82.5kg x2 1 1

Incline Hammercurls (Scott-Bank, 60°) 2x8-12
22kg x3 12.9 12.10 12.11
24kg x3 6.5
22kg x2 8.7 9.8
14kg x3 8.6 10.6 12.8
16kg x3 6.5 9.7 11.6
18kg x7 5.5 7.5 8.7 9.8 9.7 8.5 12.8
20kg x4 5.4 6.4 7.5 0.0
18kg x5 6.4 9.7 10.7 9.5 12.13
20kg x1 5.4
12kg x1 9.6

Reverse Flys (hintere Schulter) 2x8-12
20kg x1 8.7
25kg x5 7.6 8.6 9.7 10.8 12.11
27.5kg x10 7.6 7.7 8.6 7.7 7.7 8.6 9.7 7.5 8.4 x.x
25kg x2 10.5 11.9
27.5kg x1 9.8
15kg x1 5.7
12.5kg x1 13.9
15kg x2 6.6 0.0
20kg x3 8.6 9.7 10.12
22.5kg x2 6.5 8.5
30kg x2 4.6 7.4


6. Wochentag
Squat 2x2-4
100kg x1 4.4
102.5kg x1 4.3
105kg x1 4.2
107.5kg x5 2.2 4.2 4.3 0.0 4.3
110kg x3 3.1 3.2 3.3
112.5kg x2 4.2 4.4
115kg x5 2.1 3.2 3.1 2.2 4.3
117.5kg x5 3.2 3.1 4.0 0.0 0.0
110kg x2 2.1 4.3
112.5kg x3 2.1 3.1 4.5
115kg x1 2.1

Schrägbank 2x6-10
30kg x4 7.6 9.6 10.7 8.7
32kg x11 8.x 8.2 8.3 9.7 x.x 7.6 9.6 8.x 6.5 8.6
34kg x4 5.5 6.4 6.4 5.4
32kg x2 4.4 9.4
34kg x2 5.x 0.0
26kg x1 10.12
28kg x1 10.12
30kg x2 8.4 10.11
32kg x3 5.4 5.3 6.3

Flys (Stufe 3.5) 2x8-12
32.5kg x4 8.7 9.8 9.9 12.9
35kg x6 8.7 8.8 9.7 10.8 11.6 x.12
37.5kg x6 7.6 8.5 x.x 9.7 x.x 11.5
40kg x5 6.5 6.6 7.6 5.4 6.4
32.5kg x2 x.5 0.0
35kg x2 9.7 12.11
37.5kg x3 8.5 9.8 12.14
40kg x2 7.4 10.9

Kurzhantel Schulterdrücken (75°) 2x6-10
20kg x1 6.10
22kg x4 7.6 8.7 9.8 10.8
24kg x5 6.5 7.6 8.6 9.7 10.5
26kg x11 5.4 5.3 6.5 7.5 7.4 7.6 7.6 8.6 6.5 7.6
28kg x2 x.4 0.0
24kg x3 7.6 5.4 10.9
26kg x4 7.5 4.8 5.4 5.4

Scullcrushers 2x8-12
30kg x1 12.8
32.5kg x5 8.7 8.8 11.8 12.10 12.11
35kg x3 8.6 9.6 12.9
37.5kg x5 7.5 2.1 10.9 11.9 12.7
40kg x4 7.6 9.6 9.7 11.7
42.5kg x2 4.4 5.3
25kg x3 6.6 9.12 0.0
20kg x2 9.8 12.14
22.5kg x2 10.7 12.15
12.5kg x2 8.7 12.13
13.75kg x1 8.7

Bulgarian Split Squats (Langhantel) 2x6-10
60kg x3 8.6 7.6 10.8
62.5kg x1 10.10
65kg x3 10.10 8.7 0.0
67.5kg x1 10.10
70kg x1 10.10
75kg x2 0.0 10.10
80kg x1 10.10
85kg x2 7.5 10.10
90kg x2 6.5 10.5
95kg x4 6.5 8.4 0.0 5.5
80kg x3 10.5 0.0 0.0
60kg x2 7.5 10.7
65kg x1 10.10
70kg x1 10.10
75kg x2 7.4 10.5

Seitheben 2x8-20
14kg x4 9.8 10.8 10.9 12.8
16kg x16 7.6 8.6 7.5 8.6 9.6 9.8 0.0 6.5 7.6 9.7 8.6 x.x x.7 8.7 6.5 7.6
25kg x3 8.6 9.7 0.0
5kg x6 10.9 11.1 8.7 8.8 10.8 9.6
12kg x2 14.12 15.11
''';
