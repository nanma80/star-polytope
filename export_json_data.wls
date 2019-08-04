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

For[i=1,i<=Length[shapes],i++,
	shape = shapes[[i]];
	outputFileName = shape <> ".json";
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	outputFileName = FileNameJoin[{dataFolder, outputFileName}];

	Print["Reading data for " <> shape <> " from " <> dataFileName];

	cells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];
	cellsGoldenField=Map[toGoldenField, cells, {4}];
	Print["Mapped values to the golden ratio field"];

	vertices = Union[Flatten[cellsGoldenField,2]];
	verticesMap = getMap[vertices];

	faces = Union[Flatten[cellsGoldenField,1], SameTest -> sameCenter];
	edgesPerFace = Map[getEdgesFromFace, faces];
	edges = Union[Flatten[edgesPerFace,1], SameTest -> sameCenter];
	edgeIndices = Map[Sort[Map[verticesMap, #]]&, edges];
	edgeCenters = Map[Total, edges];
	edgeCentersMap = getMap[edgeCenters];
	edgeCenterPerFace = Map[getCenter, edgesPerFace, {2}];

	faceIndices = Map[Sort[Map[edgeCentersMap, #]]&, edgeCenterPerFace];
	faceCenters = Map[Total, faces];
	faceCentersMap = getMap[faceCenters];

	faceCentersPerCell = Map[Total[#, {2}]&, cellsGoldenField];
	cellIndices = Map[Sort[Map[faceCentersMap, #]]&, faceCentersPerCell];

	polytopeData = <|
		"vertices" -> vertices,
		"edges" -> edgeIndices - 1,
		"faces" -> faceIndices - 1,
		"cells" -> cellIndices - 1
	|>;

	Export[outputFileName, polytopeData, "RawJSON", Compact -> True];
	Print["saved json data to " <> outputFileName];
]
