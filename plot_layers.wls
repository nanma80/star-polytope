#!/usr/bin/env wolframscript

(*
mogrify -crop 450x450+75+0 -path . pov_*.png
mogrify -crop 300x300+50+0 -path . explode*.gif
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

shape = "test";

activeLayer = 3;
exportToPov = True;

dataFolder = "data";

dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}]

Print["Reading data for " <> shape <> " from " <> dataFileName];



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
getCellCenter[cell_] := Simplify[Total[Flatten[cell, 1]]];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
explodedCell[cell_, explosionFactor_] := Map[(# + Mean[Map[Mean,cell]] * explosionFactor)&, cell, {2}];

outputFileName = shape <> "_layer_" <> IntegerString[activeLayer] <> ".png";
imageFolder = "output";
If[exportToPov, outputFileName = "pov_" <> outputFileName ];
outputFileName = FileNameJoin[{imageFolder, outputFileName}];
imageSize = {600, 450}; (* has to be 4:3 *)
(*imageSize = {1000, 750};*)
cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

cells = Get[dataFileName];

Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

cellsByLayers = GroupBy[cells, getCellCenter[#][[4]]&];
layerKeys = Sort[Keys[cellsByLayers], Greater];
Print["There are " <> IntegerString[Length[layerKeys]] <> " layers in total. Layer keys:"];
Print[N[layerKeys]];

inactiveCells = Apply[Join, Table[cellsByLayers[layerKeys[[k]]], {k, 1, activeLayer - 1}]];

Print["Selected " <> IntegerString[Length[inactiveCells]] <> " inactive cells."];

activeCells = cellsByLayers[layerKeys[[activeLayer]]];
Print["Selected " <> IntegerString[Length[activeCells]] <> " active cells."];

activeCells = Map[explodedCell[#, 30 / 100.0]&, activeCells];

activeFaces = Union[ Flatten[activeCells, 1], SameTest -> sameCenter];
activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter];
activeVertices = Union[ Flatten[activeFaces,1], SameTest -> sameVertex];

inactiveFaces = Union[ Flatten[inactiveCells, 1], SameTest -> sameCenter];
inactiveEdges = Union[ Flatten[Map[getEdgesFromFace, inactiveFaces], 1], SameTest -> sameCenter];
inactiveVertices = Union[ Flatten[inactiveFaces,1], SameTest -> sameVertex];

(*
Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];
Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];
Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];
*)

thinkness = Norm[cells[[1]][[1]][[1]]] * 0.008;
lighting = {{"Point", White, {10, -10, 10}}};

shapeTokens = StringSplit[shape, "_"];
If[Length[shapeTokens] < 3,
	color = Red,

	cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
	colors = <|
		"3_3" -> Cyan,
		"5_3" -> Red,
		"3_5" -> Green,
		"52_5" -> Blue,
		"5_52" -> Yellow,
		"52_3" -> Magenta,
		"3_52" -> Purple
	|>;
	color = colors[cellShape];
]

graph = Graphics3D[
	{
		{
			Opacity[0.9], FaceForm[Darker[color, 0.5]], Map[Polygon, Map[projectTo3d, inactiveFaces, {2}]]
		},
		{
			Opacity[0.9], FaceForm[White], Map[Cylinder[#, thinkness]&, Map[projectTo3d, inactiveEdges, {2}]]
		},
		{
			Opacity[0.9], FaceForm[White], Map[Sphere[#, thinkness * 2]&, Map[projectTo3d, inactiveVertices]]
		},

		{
			Opacity[0.4], FaceForm[Lighter[color, 0.3]], Map[Polygon, Map[projectTo3d, activeFaces, {2}]]
		},
		{
			Opacity[0.9], FaceForm[White], Map[Cylinder[#, thinkness]&, Map[projectTo3d, activeEdges, {2}]]
		},
		{
			Opacity[0.9], FaceForm[White], Map[Sphere[#, thinkness * 2]&, Map[projectTo3d, activeVertices]]
		}
	},
(*	ViewPoint -> vertices[[7]] * 3, *)
	Lighting -> lighting
];


If[exportToPov,
	If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
	POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
	Run[cropCommand];
	,
	Export[outputFileName, graph];
]
Print["Saved the image to " <> outputFileName];

