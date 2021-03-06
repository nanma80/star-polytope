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
getStellatedVertex[a_, b_] := (b-a)*GoldenRatio^3 + b;

exportPolyhedron[shape_] := Module[
	{outputFileName, imageSize, vertices, edges, faces, thickness, lighting, graph},

	outputFileName = "stellated_icosahedron.png";
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
	range = 2.5 * Norm[vertices[[1]]];
	color = allColors[ allSchlaefliSymbols[shape]];
	viewPoint = If[specialViewPoint, 
		If[shape == "SmallStellatedDodecahedron", -vertices[[1]]*10, {0, 0, 1}*10], 
		{3, -3, 5}*3
	];

	
	a = vertices[[8]];
	aprime = (vertices[[2]]+vertices[[12]])/2;
	vertexa = getStellatedVertex[a, aprime];

 	b = vertices[[12]];
	bprime = (vertices[[2]]+vertices[[8]])/2;
	vertexb = getStellatedVertex[b, bprime];

 	c = vertices[[2]];
	cprime = (vertices[[12]]+vertices[[8]])/2;
	vertexc = getStellatedVertex[c, cprime];

 	d = vertices[[11]];
	dprime = (vertices[[9]]+vertices[[5]])/2;
	vertexd = getStellatedVertex[d, dprime];

	specialVertices = {vertexa, vertexb, vertexc, vertexd};

	newFaces = { 
		{vertexa, vertexb, vertexd},
		{vertexa, vertexb, vertexc}
	};

	newEdges = Map[getEdgesFromFace, newFaces];

	extendedFaces = {
		{vertices[[9]], vertices[[5]], vertices[[11]]},
		{vertices[[2]], vertices[[8]], vertices[[12]]}
	};
	viewCenter = {-0.55, 0, -0.8};

	graph = Graphics3D[
		{
			{
				Opacity[0.3], FaceForm[color], faces
			},
			{
				FaceForm[White], Map[Cylinder[#, thickness]&, edges]
			},
			{
				FaceForm[White], Map[Sphere[#, thickness * 2]&, vertices]
			},
(* 			{
				Table[Text[Style[IntegerString[k], Large, Bold], vertices[[k]]*1.1], {k, 1, Length[vertices]}]
			}, *)
  			{
				Opacity[0.3], FaceForm[Orange], Map[Polygon, newFaces]
			},
  			{
				FaceForm[White], Map[Polygon, extendedFaces*1.01]
			},
			{
				FaceForm[Orange], Map[Cylinder[#, thickness]&, newEdges]
			},
			{
				FaceForm[Orange], Map[Sphere[#, thickness * 3]&, specialVertices]
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
	"Icosahedron"
};

Map[exportPolyhedron, shapes];

