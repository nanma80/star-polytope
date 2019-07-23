#!/usr/bin/env wolframscript

(* 
shape = "test";
shape = "cell120";
shape = "cell600";
shape = "polytope_3_5_52";
shape = "polytope_52_5_3";
shape = "polytope_5_52_5";
shape = "polytope_5_3_52";
shape = "polytope_52_5_52";
*)

shape = "polytope_3_52_5";

dataFolder = "data";

dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}]

Print["Reading data for " <> shape <> " from " <> dataFileName];

exportToPov = True;
plotAllCells = True;


Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCellCenter[cell_] := Total[Flatten[cell, 1]];


outputFileName = shape <> ".png";
imageFolder = "output";
If[exportToPov, outputFileName = "pov_" <> outputFileName ];
outputFileName = FileNameJoin[{imageFolder, outputFileName}];
imageSize = {600, 450};

cells = Get[dataFileName];

If[plotAllCells,
	(* doing nothing *) True,
	cells = Select[cells, (getCellCenter[#][[1]] == 0 && getCellCenter[#][[2]] == 0 && getCellCenter[#][[3]] == 0 && getCellCenter[#][[4]] >= 0)&];
]

Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

faces = Union[ Flatten[cells, 1], SameTest -> sameCenter];
edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];
Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];
Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];

thinkness = Norm[vertices[[1]]] * 0.008;
lighting = {{"Point", White, {10, -10, 10}}};

graph = Graphics3D[
	{
		{
			Opacity[0.7], FaceForm[Pink], Map[Polygon, Map[projectTo3d, faces, {2}]]
		},
		{
			Opacity[0.9], FaceForm[Red], Map[Cylinder[#, thinkness]&, Map[projectTo3d, edges, {2}]]
		},
		{
			Opacity[0.9], FaceForm[Darker[Red]], Map[Sphere[#, thinkness * 2]&, Map[projectTo3d, vertices]]
		}
	},
(*	ViewPoint -> vertices[[7]] * 3, *)
	Lighting -> lighting
];


If[exportToPov,
	If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
	POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize];
	,
	Export[outputFileName, graph]
]
Print["Saved the image to " <> outputFileName];

