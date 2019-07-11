#!/usr/bin/env wolframscript

exportToPov = False;

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

# PolyhedronData["KeplerPoinsot"]                                                        
# {GreatDodecahedron, GreatIcosahedron, GreatStellatedDodecahedron, SmallStellatedDodecahedron}

exportPolyhedron[shape_] := Module[
	{outputFileName, imageSize, vertices, edges, faces, thinkness, lighting, graph},
	outputFileName = shape <> ".png";
	If[exportToPov, outputFileName = "pov" <> outputFileName ];
	imageSize = {400, 300};

	vertices = PolyhedronData[shape, "Vertices"];
	edges = PolyhedronData[shape, "EdgeCoordinates"];
	faces = PolyhedronData[shape, "Polygons"];
	thinkness = Norm[vertices[[1]]] * 0.02;
	lighting = {{"Point", White, {10, -10, 10}}};

	graph = Graphics3D[
		{
			{
				Opacity[0.5], FaceForm[Pink], faces
			},
			{
				Opacity[0.9], FaceForm[Red], Map[Cylinder[#, thinkness]&, edges]
			},
			{
				Opacity[0.9], FaceForm[Darker[Red]], Map[Sphere[#, thinkness * 2]&, vertices]
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
]

shapes = {"GreatDodecahedron", "GreatIcosahedron", "GreatStellatedDodecahedron", "SmallStellatedDodecahedron"};

(*shapes = {"GreatDodecahedron"};*)

Map[exportPolyhedron, shapes];



