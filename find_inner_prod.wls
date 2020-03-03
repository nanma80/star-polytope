#!/usr/bin/env wolframscript


(* shapes = {
	(* "test", *)
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
 *)

shapes = {
	(* "test", *)
	(* "polytope_3_3_4" *)
	(* "polytope_3_4_3" *)
	"polytope_3_3_5_cell600"
};

(* shape = "polytope_3_52_5"; *)

dataFolder = "data";

phi = GoldenRatio;
(* for 600 cell, 5{4}3 *)
(* targetInnerProds = {Sqrt[(1 + Sqrt[(5 + 2*Sqrt[5])/15])/2], Sqrt[(5 + 2*Sqrt[5])/15]}; *)
(* targetInnerProds = {0.45529649865501276, 0.7366852097826335}; *)
(* targetInnerProds = {0.5228511020787892, 0.6338497452485641, 0.7328667969030407, 0.766360424875417, 0.8142632253284559, 0.8459908542188238, 0.9265733799181644, 0.9290548650362505, 0.9472735804116371, 0.9781476007338055}; *)
(* targetInnerProds = {0.35486738103039833, 0.4999999999999972, 0.5490927356975517, 0.574187484005847, 0.6338497452485632, 0.6942253546671512, 0.73286679690304, 0.7663604248754161, 0.7684128386730007, 0.7839222460666511, 0.8090169943749458, 0.814263225328455, 0.8459908542188233, 0.8884507093343049, 0.9265733799181641, 0.92905486503625, 0.9472735804116368, 0.9781476007338054}; *)
targetInnerProds = {0.5490927356975517, 0.8884507093343049};
targetInnerProds = {0.5490927356975517};

(* for 4{4}3 *)
(* targetInnerProds = {Cos[ArcSec[Sqrt[3]]/2], Cos[ArcSec[Sqrt[3]]]}; *)

Print[targetInnerProds//N];
(* epsilon = 0.2; *)
epsilon = 0.000001;

exportToPov = True;
checkAllCells = True;

getProjectionMatrix[direction_] := Simplify[Orthogonalize[{direction, {2, -1.4, 0.3, 0.9}, {0, 1, 2.3, 0.8}, {0.5, 0.3, 1, 0.1}}]][[2;;4]];
projectToDirection[vertex4d_, projectionMatrix_] := projectionMatrix.vertex4d;
projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCellCenter[cell_] := Total[Flatten[cell, 1]];
NormalizedDot[a_, b_] := FullSimplify[Dot[a, b]/Norm[a]/Norm[b]];


For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	shape = shapes[[shapeIndex]];
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];

	outputFileName = "partition_face_centers_" <> shape <> ".png";
	imageFolder = "output";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{imageFolder, shape, outputFileName}];
	imageSize = {600, 450}; (* has to be 4:3 *)
	(*imageSize = {1000, 750};*)
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	cells = Get[dataFileName];

	If[checkAllCells,
		(* doing nothing *) True,
		cells = {cells[[1]]}
	];

	Print["Original shape: " <> ToString[shape]];

	faces = Union[ Flatten[cells, 1], SameTest -> sameCenter];
	edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
	vertices = Union[ Flatten[faces,1], SameTest -> sameVertex];

	Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];
	Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];
	Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

	flatCells = Map[Flatten[#, 1]&, cells];
	rawCellCenters = Map[Mean, flatCells];
	rawFaceCenters = Map[Mean, faces];
	rawEdgeCenters = Map[Mean, edges];

	nVertices = vertices/Norm[vertices[[1]]];
	nFaces = rawFaceCenters/Norm[rawFaceCenters[[1]]];
	nEdges = rawEdgeCenters/Norm[rawEdgeCenters[[1]]];
	nCells = rawCellCenters/Norm[rawCellCenters[[1]]];


	vertex1 = nVertices[[1]];
	face1 = nFaces[[1]];
	edge1 = nEdges[[1]];
	cell1 = nCells[[1]];

	rawFaceCenter1 = {(3 + Sqrt[5])/3, 0, 2/3, 0};
	rawEdgeCenter1 = {(5 + Sqrt[5])/4, (1 + Sqrt[5])^(-1), -1/2, 0};
	faceCenter1 = rawFaceCenter1/Norm[rawFaceCenter1];
	edgeCenter1 = rawEdgeCenter1/Norm[rawEdgeCenter1];

	(* compare1 = {vertex1, face1, edge1, cell1}//Simplify; *)
	(* compare2 = Join[nVertices, nFaces, nEdges, nCells]; *)

	(* compare1 = {vertex1}; *)
	(* compare2 = nEdges; *)

	(* compare1 = {face1}; *)
	compare1 = {faceCenter1};
	compare2 = nEdges;

	(* compare1 = {edgeCenter1}; *)
	(* compare2 = nFaces; *)
	
	(* compare1 = {edge1}; *)
	(* compare2 = nVertices; *)

	(* compare1 = {cell1}; *)
	(* compare2 = nFaces; *)


	Print[{Length[compare1], Length[compare2]}];
	targetIndices = {};
	hitCount = 0;
	For[i1 = 1, i1 <= Length[compare1], i1++,
		For[i2 = 1, i2 <= Length[compare2], i2++,
			inner = compare1[[i1]].compare2[[i2]];
			For[targetIndex = 1, targetIndex <= Length[targetInnerProds], targetIndex++,
				If[
					Abs[inner - targetInnerProds[[targetIndex]]] < epsilon,
					hitCount ++;
					AppendTo[targetIndices, targetIndex];
					Print[{
							shape, 
							N[inner],
							i1, i2, targetIndex, 
							N[compare1[[i1]]],
							N[compare2[[i2]]]
						}];
				];
			];
		];
	];
	Print["hit count: " <> IntegerString[hitCount]];
];
uniqueTargetIndices = Union[targetIndices];
Print[uniqueTargetIndices];
Print[Map[targetInnerProds[[#]]&, uniqueTargetIndices]];

(* 
For 600-cell, for the second target (cos 2 sigma) 
Around each face, there are 15 matching edges.
Around each edge, there are 25 matching faces.

For 4{4}3, from 16-cell, the inner prod is between a vertex and a face center.
from 24-cell, it can be found between:
a vertex and 12 edges
a face and 3 cells
an edge and 3 vertices
a cell and 12 faces

*)