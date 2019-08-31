#!/usr/bin/env wolframscript


shapes = {
	"test",
	"polytope_5_3_3_cell120",
	"polytope_3_3_5_cell600",
	"polytope_3_5_52",
	"polytope_52_5_3",
	"polytope_5_52_5",
	"polytope_5_3_52",
	"polytope_52_3_5",
	"polytope_52_5_52",
	"polytope_5_52_3",
	"polytope_3_52_5",
	"polytope_3_3_52",
	"polytope_52_3_3"
};

dataFolder = "data";

(*
shapes = {
	"test"
};
*)

basicShape = "polytope_5_3_3_cell120";
shapes = {
	(* base *)
	"polytope_5_3_3_cell120",
	"polytope_52_5_3",
	"polytope_5_52_5",
	"polytope_52_3_5",

	(* middle latitude cells *)
	"polytope_3_5_52",
	"polytope_3_52_5",

	(* low latitude of the southern hemisphere *)
	"polytope_5_3_52",
	"polytope_52_5_52",
	"polytope_5_52_3",
	"polytope_52_3_3"
};

(* 
Inner products between cells of polytope_5_3_3_cell120
{1, (1 + Sqrt[5])/4, 1/2, (-1 + Sqrt[5])/4, 0, (1 - Sqrt[5])/4, -1/2, (-1 - Sqrt[5])/4, -1}
{1., 0.8090169943749475, 0.5, 0.30901699437494745, 0., -0.30901699437494745, -0.5, -0.8090169943749475, -1.}
Number of layers:
9
{polytope_5_3_3_cell120, (1 + Sqrt[5])/4, 0.8090169943749475}
{polytope_52_5_3, (1 + Sqrt[5])/4, 0.8090169943749475}
{polytope_5_52_5, (1 + Sqrt[5])/4, 0.8090169943749475}
{polytope_52_3_5, (1 + Sqrt[5])/4, 0.8090169943749475}
{polytope_3_5_52, 1/2, 0.5}
{polytope_3_52_5, 1/2, 0.5}
{polytope_5_3_52, (1 - Sqrt[5])/4, -0.30901699437494745}
{polytope_52_5_52, (1 - Sqrt[5])/4, -0.30901699437494745}
{polytope_5_52_3, (1 - Sqrt[5])/4, -0.30901699437494745}
{polytope_52_3_3, (1 - Sqrt[5])/4, -0.30901699437494745}
*)

basicShape = "polytope_3_3_5_cell600";
shapes = {
	(* base *)
	"polytope_3_3_5_cell600",
	(* a layer on the southern hemisphere *)
	"polytope_3_3_52"
};

(* 
Inner products between cells of polytope_3_3_5_cell600
{1, (1 + 3*Sqrt[5])/8, (5 + Sqrt[5])/8, (1 + Sqrt[5])/4, 3/4, (-1 + 3*Sqrt[5])/8, (3 + Sqrt[5])/8, Sqrt[5]/4, 1/2, (1 + Sqrt[5])/8, (5 - Sqrt[5])/8, (-1 + Sqrt[5])/4, 1/4, (-1 + Sqrt[5])/8, (3 - Sqrt[5])/8, 0, (-3 + Sqrt[5])/8, (1 - Sqrt[5])/8, -1/4, (1 - Sqrt[5])/4, (-5 + Sqrt[5])/8, (-1 - Sqrt[5])/8, -1/2, -Sqrt[5]/4, (-3 - Sqrt[5])/8, (1 - 3*Sqrt[5])/8, -3/4, (-1 - Sqrt[5])/4, (-5 - Sqrt[5])/8, (-1 - 3*Sqrt[5])/8, -1}
{1., 0.9635254915624212, 0.9045084971874737, 0.8090169943749475, 0.75, 0.7135254915624212, 0.6545084971874737, 0.5590169943749475, 0.5, 0.4045084971874737, 0.3454915028125263, 0.30901699437494745, 0.25, 0.15450849718747373, 0.09549150281252627, 0., -0.09549150281252627, -0.15450849718747373, -0.25, -0.30901699437494745, -0.3454915028125263, -0.4045084971874737, -0.5, -0.5590169943749475, -0.6545084971874737, -0.7135254915624212, -0.75, -0.8090169943749475, -0.9045084971874737, -0.9635254915624212, -1.}
Number of layers:
31
{polytope_3_3_5_cell600, (1 + 3*Sqrt[5])/8, 0.9635254915624212}
{polytope_3_3_52, (1 - 3*Sqrt[5])/8, -0.7135254915624212}
*)

projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCenter[edge_] := Total[edge];
getCellCenter[cell_] := Simplify[Total[Flatten[cell, 1]]];
toGoldenField[value_] := If[value < 0,
	-toGoldenField[-value],
	If[value <= 1,
		If[value < 1/GoldenRatio,
			If[value == 0,
				{0, 0}, (* 0 *)
				If[value == 1/GoldenRatio^2,
					{2, -1}, (* 1/phi^2 *)
					Throw[value]
				]
			],
			If[value == 1/GoldenRatio,
				{-1, 1}, (* 1/phi *)
				If[value == 1,
					{1, 0}, (*1*)
					Throw[value]
				]
			]
		],
		If[value <= 2,
			If[value == GoldenRatio,
				{0, 1}, (* phi *)
				If[value == 2,
					{2, 0}, (* 2 *)
					Throw[value]
				]
			],
			If[value == Sqrt[5],
				{-1, 2}, (* sqrt(5) *)
				If[value == GoldenRatio^2,
					{1, 1}, (* phi^2 *)
					Throw[value]
				]
			]
		]
	]
]
getMap[list_] := Association[Table[{list[[k]] -> k}, {k, 1, Length[list]}]];
NormalizedDot[a_, b_] := FullSimplify[Dot[a, b]/Norm[a]/Norm[b]];

outputFileName = basicShape <> ".json";
dataFileName = FileNameJoin[{dataFolder, basicShape <> ".wl"}];
outputFileName = FileNameJoin[{dataFolder, outputFileName}];
(* Print["Reading data for " <> basicShape <> " from " <> dataFileName]; *)
basicCells = Get[dataFileName];

cosines = Map[NormalizedDot[getCellCenter[basicCells[[1]]], getCellCenter[#]]&, basicCells];
distinctCosines = Sort[Union[cosines, SameTest -> sameVertex], Greater];
Print["Inner products between cells of " <> basicShape];
Print[distinctCosines];
Print[distinctCosines//N];

Print["Number of layers: "];
Print[distinctCosines//Length];

For[i=1,i<=Length[shapes],i++,
	shape = shapes[[i]];
	outputFileName = shape <> ".json";
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	outputFileName = FileNameJoin[{dataFolder, outputFileName}];

	(* Print["Reading data for " <> shape <> " from " <> dataFileName]; *)

	cells = Get[dataFileName];
	face1 = cells[[1]][[1]];

	neighborCells = Select[cells, Length[Intersection[#, { face1 }, SameTest -> sameCenter ]] > 0 & ];
	neighborCellCenters = Map[getCellCenter, neighborCells];
	(* Print["Found " <> IntegerString[Length[neighborCells]] <> " cells sharing a face."]; *)
	cosine = Apply[NormalizedDot, neighborCellCenters];

	Print[
		{shape, cosine, N[cosine]}
	];
];
