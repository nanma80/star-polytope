#!/usr/bin/env wolframscript

(* 
Reference:
https://en.wikipedia.org/wiki/Regular_4-polytope#Properties_2
*)


(* 
shape = "test";
shape = "polytope_5_3_3_cell120";
shape = "polytope_3_3_5_cell600";
shape = "polytope_3_5_52";
shape = "polytope_52_5_3";
shape = "polytope_5_52_5";
shape = "polytope_5_3_52";
shape = "polytope_52_3_5";
shape = "polytope_52_5_52";
shape = "polytope_5_52_3";
shape = "polytope_3_52_5";
shape = "polytope_3_3_52";
shape = "polytope_52_3_3";
*)

shape = "polytope_3_4_3";

dataFolder = "data";
AllCells = True;

Print["Generating data for " <> shape];

projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCellCenter[cell_] := Total[Flatten[cell, 1]];

dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];

phi = GoldenRatio;
configs = Get["configs.wl"]
configs = configs /.{phi -> GoldenRatio};
mirrors = configs[shape][[1]];
vertex1 = configs[shape][[2]];

face1 = {vertex1};
finished = False;
For[i=0, i < 100 && finished == False, i++,
	newVertex = doubleReflect[face1[[-1]], mirrors[[1]], mirrors[[2]]];
	If[newVertex != face1[[1]],
		AppendTo[face1, newVertex],
		finished = True;
	]
]
Print["Each face contains " <> IntegerString[Length[face1]] <> " vertices."];

cell1 = {face1};
countStart = -1;
For[i=0, i < 100 && countStart != Length[cell1], i++,
	countStart = Length[cell1];
	
	For[mirrorIndex = 3, mirrorIndex >= 1, mirrorIndex--,
		cell1 = Union[cell1, Map[reflect[#, mirrors[[mirrorIndex]] ]&, cell1, {2}], SameTest -> sameCenter];
	];
]
Print["Each cell contains " <> IntegerString[Length[cell1]] <> " faces."];

cells = {cell1};
countStart = -1;
mirrorCount = If[AllCells, 4, 3];

For[i=0, i < 100 && countStart != Length[cells], i++,
	countStart = Length[cells];
	
	For[mirrorIndex = mirrorCount, mirrorIndex >= 1, mirrorIndex--,
		cells = Union[cells, Map[reflect[#, mirrors[[mirrorIndex]] ]&, cells, {3}], SameTest -> sameCellCenter];
	];

	Print["Generated " <> IntegerString[Length[cells]] <> " cells so far."];
]

(*
cells = Union[cells, Map[reflect[#, mirrors[[4]] ]&, cells, {3}], SameTest -> sameCellCenter];
*)

Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

If[FileExistsQ[dataFileName], DeleteFile[dataFileName]];
Save[dataFileName, cells];
Print["Saved cells to " <> dataFileName];
