#!/usr/bin/env wolframscript

(* 

magick convert -delay 5 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

exportToPov = True;

(* SmallStellatedDodecahedron *)
(*
rangeFactor = 1.5;
maxExplode = 280;
explodeStep = 5;
*)

(* GreatStellatedDodecahedron *)
(*
rangeFactor = 1.5;
maxExplode = 800;
explodeStep = 20;
*)

(* GreatDodecahedron *)
(*
rangeFactor = 1.5;
maxExplode = 300;
explodeStep = 6;
*)

(* GreatIcosahedron *)

rangeFactor = 1.5;
maxExplode = 1400;
explodeStep = 28;


Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];

explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];

exportPolyhedron[shape_, explosionPercent_] := Module[
	{outputFileName, imageSize, vertices, edges, faces, originalFacesCoordinates, facesCoordinates, edgesCoordinates, thinkness, lighting, graph},
	outputFileName = "explode" <> shape <> IntegerString[explosionPercent, 10, 4] <>".png";
	If[exportToPov, outputFileName = "pov" <> outputFileName ];
	imageSize = {400, 300};

	faces = PolyhedronData[shape, "Polygons"];
	originalFacesCoordinates = Map[PolygonCoordinates, faces];
	facesCoordinates = Map[explodedFace[#, explosionPercent / 100.0]&, originalFacesCoordinates];
	edgesCoordinates = Map[getEdgesFromFace, facesCoordinates];
	vertices = Flatten[facesCoordinates,1];
	edges = Flatten[edgesCoordinates,1];

	thinkness = Norm[originalFacesCoordinates[[1]][[1]]] * 0.03;
	lighting = {{"Point", White, {10, -10, 10}}};

	range = Max[originalFacesCoordinates] * rangeFactor;

	graph = Graphics3D[
		{
			{
				Opacity[0.5], FaceForm[Pink], Map[Polygon, facesCoordinates]
			},
			{
				Opacity[0.9], FaceForm[Red], Map[Cylinder[#, thinkness]&, edges]
			},
			{
				Opacity[0.9], FaceForm[Darker[Red]], Map[Sphere[#, thinkness * 2]&, vertices]
			}
		},
	(*	ViewPoint -> vertices[[7]] * 3, *)
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		Lighting -> lighting
	];


	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize];
		,
		Export[outputFileName, graph]
	]
]

(*
PolyhedronData["Platonic"]
{Tetrahedron, Cube, Octahedron, Dodecahedron, Icosahedron}

PolyhedronData["KeplerPoinsot"]
{GreatDodecahedron, GreatIcosahedron, GreatStellatedDodecahedron, SmallStellatedDodecahedron}
*)

shapes = {"GreatDodecahedron", "GreatIcosahedron", "GreatStellatedDodecahedron", "SmallStellatedDodecahedron"};

shapes = {"GreatIcosahedron"};

(*shapes = {"Dodecahedron"}*)

(*Map[exportPolyhedron, shapes];*)

(*
exportPolyhedron[shapes[[1]], 1400];
*)

Table[ exportPolyhedron[shapes[[1]], k], {k, 0, maxExplode, explodeStep} ]



