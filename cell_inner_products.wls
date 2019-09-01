#!/usr/bin/env wolframscript

basedOn600Cell = True;

dataFolder = "data";

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

If[basedOn600Cell,
	basicShape = "polytope_3_3_5_cell600";
	shapes = {
		(* base *)
		"polytope_3_3_5_cell600",
		(* a layer on the southern hemisphere *)
		"polytope_3_3_52"
	};
];


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
getMap[list_] := Association[Table[{list[[k]] -> k}, {k, 1, Length[list]}]];
NormalizedDot[a_, b_] := FullSimplify[Dot[a, b]/Norm[a]/Norm[b]];

outputFileName = basicShape <> ".json";
dataFileName = FileNameJoin[{dataFolder, basicShape <> ".wl"}];
outputFileName = FileNameJoin[{dataFolder, outputFileName}];
basicCells = Get[dataFileName];

cosines = Map[NormalizedDot[getCellCenter[basicCells[[1]]], getCellCenter[#]]&, basicCells];
distinctCosines = Sort[Union[cosines, SameTest -> sameVertex], Greater];
Print["Inner products between cell centers of " <> basicShape];
Print[distinctCosines];
Print[distinctCosines//N];

Print["Number of layers: "];
Print[distinctCosines//Length];

vertex1 = basicCells[[1]][[1]][[1]];
cosinesCV = Map[NormalizedDot[vertex1, getCellCenter[#]]&, basicCells];
distinctCosinesCV = Sort[Union[cosinesCV, SameTest -> sameVertex], Greater];

Print["Inner products between a vertex and cell centers of " <> basicShape];
Print[distinctCosinesCV];
Print[distinctCosinesCV//N];

Print["Number of layers: "];
Print[distinctCosinesCV//Length];

Print["Inner products between a cell center and its vertex:"];
For[i=1,i<=Length[shapes],i++,
	shape = shapes[[i]];
	outputFileName = shape <> ".json";
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	outputFileName = FileNameJoin[{dataFolder, outputFileName}];

	cells = Get[dataFileName];
	cell1 = cells[[1]];
	cellCenter1 = getCellCenter[cell1];
	vertex1 = cell1[[1]][[1]];
	cosine = NormalizedDot[vertex1, cellCenter1];
	Print[
		{shape, cosine, N[cosine]}
	];
];

Print["Inner products between adjacent cell centers:"];
For[i=1,i<=Length[shapes],i++,
	shape = shapes[[i]];
	outputFileName = shape <> ".json";
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	outputFileName = FileNameJoin[{dataFolder, outputFileName}];
	cells = Get[dataFileName];
	face1 = cells[[1]][[1]];

	neighborCells = Select[cells, Length[Intersection[#, { face1 }, SameTest -> sameCenter ]] > 0 & ];
	neighborCellCenters = Map[getCellCenter, neighborCells];
	cosine = Apply[NormalizedDot, neighborCellCenters];

	Print[
		{shape, cosine, N[cosine]}
	];
];
