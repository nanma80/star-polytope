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

	outputFileName = "stellated_dodecahedron_3.png";
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
	range = 2.0 * Norm[vertices[[1]]];
	color = allColors[ allSchlaefliSymbols[shape]];
	viewPoint = If[specialViewPoint, 
		If[shape == "SmallStellatedDodecahedron", -vertices[[1]]*10, {0, 0, 1}*10], 
		{2, -3, 2}*3
	];

	a1 = vertices[[16]];
	b1 = vertices[[7]];
	vertex1 = getPentagramVertex[a1, b1];

	a2 = vertices[[8]];
	b2 = vertices[[12]];
	vertex2 = getPentagramVertex[a2, b2];

	newVertex1 = getPentagramVertex[vertex2, vertex1];
	newVertex2 = getPentagramVertex[vertex1, vertex2];


	specialVertices = {newVertex1, newVertex2}*1.01;

	newEdges = {{vertices[[7]], newVertex1}, {vertices[[19]], newVertex1},
				{vertices[[12]], newVertex2}, {vertices[[2]], newVertex2}, 
					{newVertex1, newVertex2}}*1.01;

	newFaces = {{vertices[[16]], vertices[[8]], newVertex2, newVertex1},
				{vertices[[17]], vertices[[13]], newVertex2, newVertex1}}*1.01;

	viewCenter = {0.4, 0, 0};

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
				Table[Text[IntegerString[k], vertices[[k]] + {0.1, 0.1, 0.1}], {k, 1, Length[vertices]}]
			},
 			{
				Opacity[0.3], FaceForm[Green], Map[Polygon, newFaces]
			},
			{
				FaceForm[Green], Map[Cylinder[#, thickness]&, newEdges]
			},
			{
				FaceForm[Green], Map[Sphere[#, thickness * 3]&, specialVertices]
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
	"Dodecahedron"
};

Map[exportPolyhedron, shapes];

