// Atlas coordinates are measured per character, never inferred from equal columns.
var sprites = [
    { version: 3, body: [64,3,529,1019],
      eyes: [[217,139,43,32],[278,148,48,29]], blinkOffset: [529,0],
      tail: [1126,377,370,334], tailRoot: [1150,630], hip: [360,485],
      ear: [[340,70],[391,52],[389,84],[370,122]], earPivot: [356,85] },
    { body: [136,0,342,1006], eyes: [[243,109,43,35],[298,124,40,28]], blinkOffset: [480,0],
      tail: [1092,363,356,311], tailRoot: [1120,612], hip: [260,425],
      ear: [[324,31],[375,21],[365,74],[348,89]], earPivot: [345,64] },
    { version: 3, body: [76,4,502,1012], eyes: [[330,121,46,38],[391,141,43,36]], blinkOffset: [504,0],
      tail: [1164,385,334,349], tailRoot: [1190,662], hip: [422,475],
      ear: [[445,63],[496,48],[489,85],[470,118]], earPivot: [461,87] },
    { version: 4, body: [114,5,403,1014], eyes: [[327,130,44,33],[391,149,39,33]], blinkOffset: [489,0],
      tail: [1143,434,294,249], tailRoot: [1165,616], hip: [424,486],
      ear: [[439,78],[492,59],[486,99],[468,127]], earPivot: [465,99] },
    { version: 3, body: [16,0,590,1016], boundary: [[16,0],[610,0],[610,576],[570,576],[570,1016],[16,1016]],
      eyes: [[307,120,34,25],[356,106,41,30]], blinkOffset: [555,0],
      tail: [1192,341,323,352], tailRoot: [1220,642], hip: [454,429],
      ear: [[392,39],[428,7],[435,39],[429,92],[410,80]], earPivot: [416,64] },
    { body: [205,0,360,1015], eyes: [[327,305,44,35],[390,316,42,33]], blinkOffset: [448,0],
      tail: [1117,398,350,267], tailRoot: [1144,602], hip: [384,546],
      ear: [[436,267],[483,245],[472,291],[450,311]], earPivot: [452,289] },
    { version: 4, body: [153,1,379,1008], eyes: [[294,132,39,30],[348,111,45,33]], blinkOffset: [478,0],
      tail: [1117,400,344,243], tailRoot: [1145,585], hip: [390,431],
      ear: [[353,48],[403,5],[420,41],[425,82],[408,87]], earPivot: [402,64] },
    { version: 4, body: [52,5,527,1005], eyes: [[337,124,35,26],[391,116,34,26]], blinkOffset: [542,0],
      tail: [1215,420,236,249], tailRoot: [1237,641], hip: [434,427],
      ear: [[416,50],[440,8],[451,44],[459,81],[437,74]], earPivot: [439,60] },
    { version: 4, body: [102,6,406,1011], eyes: [[248,174,51,39],[320,137,44,40]], blinkOffset: [523,0],
      tail: [1183,408,279,281], tailRoot: [1205,651], hip: [412,517],
      ear: [[168,91],[224,80],[219,121],[204,148],[186,127]], earPivot: [202,119] },
    { version: 3, body: [40,1,503,1012], shift: -21, eyes: [[257,124,40,32],[313,136,42,30]], blinkOffset: [512,0],
      tail: [1128,342,386,322], tailRoot: [1160,592], hip: [428,455],
      ear: [[246,16],[301,45],[272,77],[239,81]], earPivot: [266,63] }
];


// Keep unchanged cells; choose distinct identities within each hours/minutes pair.
function choose(digits, previous) {
    previous = previous || [];
    var next = [];
    for (var start = 0; start < digits.length; start += 2) {
        var base = start === 2 ? 2 : 0;
        var end = Math.min(start + 2, digits.length);
        for (var i = start; i < end; i++) {
            var old = previous[i];
            if (old && old.digit === Number(digits[i]) && old.variant >= base && old.variant < base + 2)
                next[i] = old;
        }
        for (var i = start; i < end; i++) {
            if (next[i]) continue;
            var digit = Number(digits[i]);
            var neighbor = next[start + (i === start ? 1 : 0)];
            var variant = base + Math.floor(Math.random() * 2);
            if (neighbor && neighbor.digit === digit) variant = base + 1 - (neighbor.variant - base);
            next[i] = { digit: digit, variant: variant };
        }
    }
    return next;
}

// A keeps the accepted originals; B is the second hour set, C/D are minute sets.
var variants = [sprites,
    [
        {"eyes":[[347,126,34,30],[407,115,35,33]],"blinkOffset":[493,0],"hip":[420,445],"ear":[[433,29],[465,7],[469,61],[449,83]],"earPivot":[449,66],"file":"assets/home-clock-v5/b0.png","body":[159,5,473,1009],"tail":[1199,491,166,136],"tailRoot":[1213,581]},
        {"eyes":[[250,121,31,28],[303,134,33,27]],"blinkOffset":[562,2],"hip":[340,405],"ear":[[344,56],[381,49],[369,95],[351,118]],"earPivot":[351,89],"file":"assets/home-clock-v5/b1.png","body":[103,19,465,984],"tail":[1280,545,167,184],"tailRoot":[1294,706]},
        {"eyes":[[285,108,34,30],[341,122,34,29]],"blinkOffset":[520,0],"hip":[400,416],"ear":[[403,58],[440,43],[432,87],[409,113]],"earPivot":[412,85],"file":"assets/home-clock-v5/b2.png","body":[112,2,406,1013],"tail":[1243,502,156,127],"tailRoot":[1257,588]},
        {"eyes":[[307,140,36,29],[365,122,35,31]],"blinkOffset":[490,0],"hip":[411,458],"ear":[[374,48],[400,10],[416,48],[415,81]],"earPivot":[399,63],"file":"assets/home-clock-v5/b3.png","body":[183,8,316,1006],"tail":[1201,497,190,168],"tailRoot":[1215,629]},
        {"eyes":[[356,119,35,29],[407,113,35,28]],"blinkOffset":[562,0],"hip":[465,475],"ear":[[437,39],[465,12],[464,56],[450,75]],"earPivot":[448,53],"file":"assets/home-clock-v5/b4.png","body":[66,9,546,998],"tail":[1244,638,191,143],"tailRoot":[1258,737]},
        {"eyes":[[335,143,33,27],[390,128,33,31]],"blinkOffset":[501,0],"hip":[432,471],"ear":[[401,42],[432,14],[447,54],[441,88]],"earPivot":[426,66],"file":"assets/home-clock-v5/b5.png","body":[171,1,386,1018],"tail":[1247,713,141,172],"tailRoot":[1261,866]},
        {"eyes":[[322,135,34,26],[373,112,31,29]],"blinkOffset":[450,0],"hip":[442,438],"ear":[[365,41],[393,8],[413,45],[416,86]],"earPivot":[396,62],"file":"assets/home-clock-v5/b6.png","body":[242,5,351,1010],"tail":[1185,355,135,160],"tailRoot":[1199,490]},
        {"eyes":[[375,121,32,30],[424,115,33,29]],"blinkOffset":[544,0],"hip":[487,457],"ear":[[439,46],[472,15],[480,59],[466,85]],"earPivot":[464,64],"file":"assets/home-clock-v5/b7.png","body":[171,6,520,989],"tail":[1244,730,158,105],"tailRoot":[1258,797]},
        {"eyes":[[317,117,33,27],[369,105,34,27]],"blinkOffset":[495,0],"hip":[432,482],"ear":[[377,39],[405,3],[421,42],[425,78]],"earPivot":[405,56],"file":"assets/home-clock-v5/b8.png","body":[145,0,379,1005],"tail":[1225,451,138,141],"tailRoot":[1239,559]},
        {"eyes":[[273,110,31,29],[324,122,33,28]],"blinkOffset":[512,0],"hip":[393,442],"ear":[[382,57],[419,41],[410,83],[391,107]],"earPivot":[394,79],"file":"assets/home-clock-v5/b9.png","body":[204,4,300,1004],"tail":[1214,460,157,163],"tailRoot":[1228,595]}
    ],
    [
        {"eyes":[[248,113,34,29],[307,126,34,29]],"blinkOffset":[524,0],"hip":[372,488],"ear":[[350,47],[382,43],[376,75],[357,98]],"earPivot":[358,72],"file":"assets/home-clock-v5/c0.png","body":[171,2,376,1015],"tail":[1215,438,175,137],"tailRoot":[1229,546]},
        {"eyes":[[294,125,34,27],[348,134,34,28]],"blinkOffset":[617,0],"hip":[474,467],"ear":[[411,53],[449,42],[435,83],[416,111]],"earPivot":[419,81],"file":"assets/home-clock-v5/c1.png","body":[34,2,571,996],"tail":[1335,601,172,153],"tailRoot":[1349,721]},
        {"eyes":[[394,113,28,27],[444,122,32,29]],"blinkOffset":[475,0],"hip":[502,465],"ear":[[495,47],[539,33],[528,77],[511,104]],"earPivot":[511,72],"file":"assets/home-clock-v5/c2.png","body":[210,1,402,1020],"tail":[1209,690,192,160],"tailRoot":[1223,805]},
        {"eyes":[[305,130,29,32],[362,144,33,32]],"blinkOffset":[554,0],"hip":[406,480],"ear":[[418,55],[461,39],[452,87],[432,110]],"earPivot":[436,83],"file":"assets/home-clock-v5/c3.png","body":[88,2,460,1014],"tail":[1262,397,160,149],"tailRoot":[1276,517]},
        {"eyes":[[216,125,32,30],[273,126,33,31]],"blinkOffset":[637,0],"hip":[331,470],"ear":[[313,43],[350,25],[345,65],[329,91]],"earPivot":[332,65],"file":"assets/home-clock-v5/c4.png","body":[75,8,567,1000],"tail":[1375,501,129,135],"tailRoot":[1389,608]},
        {"eyes":[[340,119,32,28],[394,138,34,28]],"blinkOffset":[534,0],"hip":[487,453],"ear":[[457,62],[492,56],[480,91],[464,112]],"earPivot":[464,89],"file":"assets/home-clock-v5/c5.png","body":[125,7,448,999],"tail":[1251,414,165,155],"tailRoot":[1265,540]},
        {"eyes":[[356,117,33,29],[409,106,34,31]],"blinkOffset":[517,0],"hip":[470,490],"ear":[[445,28],[476,7],[481,54],[465,78]],"earPivot":[464,58],"file":"assets/home-clock-v5/c6.png","body":[164,6,367,1008],"tail":[1230,487,151,156],"tailRoot":[1244,619]},
        {"eyes":[[367,118,29,29],[420,110,30,29]],"blinkOffset":[555,0],"hip":[490,448],"ear":[[431,34],[463,7],[469,49],[463,72]],"earPivot":[453,53],"file":"assets/home-clock-v5/c7.png","body":[74,3,476,1004],"tail":[1244,533,201,179],"tailRoot":[1258,679]},
        {"eyes":[[312,110,29,29],[367,120,31,29]],"blinkOffset":[497,1],"hip":[425,463],"ear":[[422,44],[458,34],[447,75],[431,98]],"earPivot":[435,74],"file":"assets/home-clock-v5/c8.png","body":[122,8,416,988],"tail":[1274,455,164,178],"tailRoot":[1288,611]},
        {"eyes":[[285,109,32,30],[341,118,31,29]],"blinkOffset":[506,0],"hip":[424,474],"ear":[[374,40],[409,18],[404,57],[388,88]],"earPivot":[389,65],"file":"assets/home-clock-v5/c9.png","body":[149,3,428,1012],"tail":[1255,443,154,150],"tailRoot":[1269,562]}
    ],
    [
        {"eyes":[[321,116,31,27],[373,103,33,29]],"blinkOffset":[544,0],"hip":[458,461],"ear":[[401,32],[422,4],[438,45],[430,71]],"earPivot":[420,54],"file":"assets/home-clock-v5/d0.png","body":[101,1,464,1015],"tail":[1213,443,245,180],"tailRoot":[1227,570]},
        {"eyes":[[341,120,31,27],[397,129,33,28]],"blinkOffset":[472,0],"hip":[465,455],"ear":[[447,48],[483,33],[467,76],[451,101]],"earPivot":[456,75],"file":"assets/home-clock-v5/d1.png","body":[208,4,383,1014],"tail":[1207,416,201,187],"tailRoot":[1221,561]},
        {"eyes":[[357,128,31,29],[408,113,31,31]],"blinkOffset":[500,0],"hip":[475,457],"ear":[[420,29],[445,2],[462,39],[460,65]],"earPivot":[445,48],"file":"assets/home-clock-v5/d2.png","body":[176,0,348,1001],"tail":[1184,523,180,148],"tailRoot":[1198,624]},
        {"eyes":[[257,112,32,29],[313,103,32,29]],"blinkOffset":[532,0],"hip":[363,456],"ear":[[330,27],[361,7],[370,43],[357,68]],"earPivot":[350,48],"file":"assets/home-clock-v5/d3.png","body":[160,3,364,1007],"tail":[1222,448,155,122],"tailRoot":[1236,532]},
        {"eyes":[[313,103,33,29],[365,112,34,30]],"blinkOffset":[546,0],"hip":[423,452],"ear":[[420,43],[454,29],[446,62],[429,86]],"earPivot":[435,63],"file":"assets/home-clock-v5/d4.png","body":[75,3,411,1016],"tail":[1258,417,151,164],"tailRoot":[1272,559]},
        {"eyes":[[329,116,32,29],[386,128,31,28]],"blinkOffset":[557,0],"hip":[412,446],"ear":[[439,48],[473,32],[470,66],[451,99]],"earPivot":[452,76],"file":"assets/home-clock-v5/d5.png","body":[126,0,364,1012],"tail":[1223,711,193,163],"tailRoot":[1237,839]},
        {"eyes":[[251,126,31,28],[307,118,32,30]],"blinkOffset":[590,0],"hip":[354,464],"ear":[[336,32],[365,10],[367,50],[353,75]],"earPivot":[352,52],"file":"assets/home-clock-v5/d6.png","body":[98,3,569,1002],"tail":[1288,528,176,150],"tailRoot":[1302,640]},
        {"eyes":[[320,126,31,29],[369,112,30,30]],"blinkOffset":[528,0],"hip":[408,474],"ear":[[374,40],[400,11],[418,44],[416,72]],"earPivot":[401,53],"file":"assets/home-clock-v5/d7.png","body":[132,8,404,1004],"tail":[1245,434,173,157],"tailRoot":[1259,558]},
        {"eyes":[[277,119,33,30],[332,106,32,30]],"blinkOffset":[530,0],"hip":[399,489],"ear":[[354,33],[379,3],[389,39],[383,69]],"earPivot":[373,51],"file":"assets/home-clock-v5/d8.png","body":[116,0,338,1019],"tail":[1227,407,165,139],"tailRoot":[1241,511]},
        {"eyes":[[303,117,30,34],[359,106,31,34]],"blinkOffset":[540,0],"hip":[431,482],"ear":[[420,40],[457,25],[448,66],[432,91]],"earPivot":[436,64],"file":"assets/home-clock-v5/d9.png","body":[91,10,458,1005],"tail":[1220,466,203,186],"tailRoot":[1234,603]}
    ]
];
