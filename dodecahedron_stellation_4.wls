#!/usr/bin/env wolframscript

(* the image doesn't look well. Abandon *)

exportToPov = True;
specialViewPoint = False;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

allColors = <|
	"3_3" -> Cyan,
	"5_3" -> Red,
	"3_5" -> Green,
	"52_5" -> Blue,
	"5_52" -> Yellow,
	"52_3" -> Magenta,
	"3_52" -> Orange
|>;


allSchlaefliSymbols = <|
	"Icosahedron" -> "3_5",
	"Dodecahedron" -> "5_3",
	"GreatDodecahedron" -> "5_52",
	"GreatIcosahedron" -> "3_52", 
	"GreatStellatedDodecahedron" -> "52_3", 
	"SmallStellatedDodecahedron" -> "52_5"
|>;

getFaceCenter[face_] := Simplify[Total[PolygonCoordinates[face]]/5];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
getPentagramVertex[a_, b_] := (b-a)*GoldenRatio + b;

exportPolyhedron[shape_] := Module[
	{outputFileName, imageSize, vertices, edges, faces, thickness, lighting, graph},

	outputFileName = "stellated_dodecahedron_4.png";
	imageFolder = "output";
	outputFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = FileNameJoin[{outputFolder, outputFileName}];
	imageSize = {600, 450}; (* has to be 4:3 *)
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	vertices = PolyhedronData[shape, "Vertices"];
	edges = PolyhedronData[shape, "EdgeCoordinates"];
	faces = PolyhedronData[shape, "Polygons"];
	thickness = Norm[vertices[[1]]] * 0.02;
	lighting = {{"Point", White, {10, -10, 10}}};
	range = 0.8 * Norm[vertices[[1]]];
	color = allColors[ allSchlaefliSymbols[shape]];
	viewPoint = If[specialViewPoint, 
		If[shape == "SmallStellatedDodecahedron", -vertices[[1]]*10, {0, 0, 1}*10], 
		If[shape == "SmallStellatedDodecahedron", {2.5, -3, -1}*30, {2.5, -3, 1}*30]
	];

	newFace = Map[vertices[[#]]&, {4,2,7,12,6}];

	newEdges = getEdgesFromFace[newFace];
	newFaces = {newFace} * 1.01;

	viewCenter = {0, 0, 0};

	graph = Graphics3D[
		{
			{
				FaceForm[color], faces
			},
			{
				FaceForm[White], Map[Cylinder[#, thickness]&, edges]
			},
			{
				FaceForm[White], Map[Sphere[#, thickness * 2]&, vertices]
			},
			{
				Table[Text[Style[IntegerString[k], Large, Bold, Red], vertices[[k]]*1.1], {k, 1, Length[vertices]}]
			},
  			{
				Opacity[0.7], FaceForm[Yellow], Map[Polygon, newFaces]
			},
			{
				FaceForm[Yellow], Map[Cylinder[#, thickness]&, newEdges]
			}
		},
		ViewPoint -> viewPoint,
		PlotRange -> {{viewCenter[[1]]-range, viewCenter[[1]]+range}, {viewCenter[[2]]-range, viewCenter[[2]]+range}, {viewCenter[[3]]-range, viewCenter[[3]]+range}},
		Lighting -> lighting
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph]
	];
]

shapes = {
	"SmallStellatedDodecahedron"
};

Map[exportPolyhedron, shapes];

