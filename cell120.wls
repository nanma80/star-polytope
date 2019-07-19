#!/usr/bin/env wolframscript

exportToPov = False;

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

# PolyhedronData["KeplerPoinsot"]                                                        
# {GreatDodecahedron, GreatIcosahedron, GreatStellatedDodecahedron, SmallStellatedDodecahedron}
shape = "cell120";

outputFileName = shape <> ".png";
If[exportToPov, outputFileName = "pov" <> outputFileName ];
imageSize = {400, 300};

phi = GoldenRatio;
mirrors = {
	{0, 1, 0, 0	},
	{1, phi, -1/phi, 0	},
	{1, -phi, 1/phi, 0	},
	{1, 0, phi, -1/phi	}
};

vertex1 = {0, 1/phi^2, 1, phi^2};

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
For[i=0, i < 100 && countStart != Length[cells], i++,
	countStart = Length[cells];
	
	For[mirrorIndex = 3, mirrorIndex >= 1, mirrorIndex--,
		cells = Union[cells, Map[reflect[#, mirrors[[mirrorIndex]] ]&, cells, {3}], SameTest -> sameCellCenter];
	];

	Print[Length[cells]];
]
Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

faces = Union[ Flatten[cells, 1], SameTest -> sameCenter];
edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];
Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];
Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];


(*
Print[vertices];
Print[vertices//N];
*)

thinkness = Norm[vertices[[1]]] * 0.008;
lighting = {{"Point", White, {10, -10, 10}}};



graph = Graphics3D[
	{
		{
			Opacity[0.5], FaceForm[Pink], Map[Polygon, Map[projectTo3d, faces, {2}]]
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

