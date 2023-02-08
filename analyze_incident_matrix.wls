#!/usr/bin/env wolframscript

shapes = {
	"polytope_3_3_3",
	"polytope_4_3_3",
	"polytope_3_3_4",
	"polytope_3_4_3",
	(* "polytope_3_4_3_alt" *)
	(* "polytope_5_3_52" *)
	"polytope_5_3_3_cell120"
	(* "polytope_3_3_5_cell600" *)
};

(* shapes = {
	(* "polytope_3_3_3", *)
	(* "polytope_4_3_3", *)
	(* "polytope_3_3_4", *)
	(* "polytope_3_4_3", *)
	(* "polytope_3_4_3_alt" *)
	(* "polytope_5_3_52" *)
	"polytope_5_3_3_cell120"
	(* "polytope_3_3_5_cell600" *)
};
 *)

cellCenterRelation = True;
edgeDirectionRelation = False;


dataFolder = "data";
exportToPov = True;


Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

getProjectionMatrix[direction_] := Simplify[Orthogonalize[{direction, {2, -1.4, 0.3, 0.9}, {0, 1, 2.3, 0.8}, {0.5, 0.3, 1, 0.1}}]][[2;;4]];
projectToDirection[vertex4d_, projectionMatrix_] := projectionMatrix.vertex4d;
projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]};
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];
sameCenter[set1_, set2_] := ApproxSamePoint[Total[N[set1]], Total[N[set2]]];
(* sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2]; *)
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getCellCenter[cell_] := Mean[Flatten[cell, 1]];
NormalizedDot[a_, b_] := FullSimplify[Dot[a, b]/Norm[a]/Norm[b]];
randomDirection = {1, 0.314, Pi, Exp[1]};

getEdgesDirections[edges_] := Module[
	{edgeDirections},
	edgeDirections = Map[#[[1]] - #[[2]] &, edges];
	edgeDirections = Map[If[Dot[randomDirection, #] > 0, 1, -1] * # &, edgeDirections];
	edgeDirections
];


For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	Print[];
	shape = shapes[[shapeIndex]];
	Print[shape];
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];

	outputFileName = "cut_" <> shape <> ".png";
	imageFolder = "output";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{imageFolder, shape, outputFileName}];
	imageSize = {600, 450}; (* has to be 4:3 *)
	(*imageSize = {1000, 750};*)
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	cells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

	If[cellCenterRelation,
		cellCenters = Map[getCellCenter, cells * 1.0];
		cellCenterDots = Map[NormalizedDot[cellCenters[[1]], #]&, cellCenters];
		dotsTally = Sort[Tally[Round[cellCenterDots, epsilon]]];
		Print[dotsTally];

		For[dotId = 1, dotId <= Length[dotsTally], dotId++,
			dot = dotsTally[[dotId]][[1]];
			incidentMatrix = Table[
				If[ Round[NormalizedDot[cellCenters[[i]], cellCenters[[j]]], epsilon] == dot,
				1, 0],
				{i, Length[cellCenters]}, {j, Length[cellCenters]}
			];

			matrixRank = MatrixRank[incidentMatrix, Modulus -> 2];
			Print[{dot, matrixRank}];
		];
	];

	If[edgeDirectionRelation,
		faces = Union[ Flatten[cells * 1.0, 1], SameTest -> sameCenter];
		Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];

		edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
		Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];

		vertices = Union[ Flatten[faces,1], SameTest -> ApproxSamePoint];
		Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];

		(* edgeDirections = Map[#[[1]] - #[[2]] &, edges]; *)
		(* edgeDirections = Map[If[Dot[randomDirection, #] > 0, 1, -1] * # &, edgeDirections]; *)
		edgeDirections = getEdgesDirections[edges];
		edgeDirectionTally = Tally[edgeDirections, ApproxSamePoint[#1, #2]&];
		tallyCounts = Map[#[[2]]&, edgeDirectionTally];
		Print[tallyCounts];
		tallyTally = Tally[tallyCounts];
		Print[tallyTally];
		uniqueDirections = Map[#[[1]]&, edgeDirectionTally];
		(* uniqueDirections = Sort[uniqueDirections/Norm[uniqueDirections[[1]]] * 2.0]; *)
		uniqueDirections = Sort[uniqueDirections];
		(* Map[Print, uniqueDirections]; *)

		edgeDirectionIndexMap = <||>;
		For[did = 1, did <= Length[uniqueDirections], did++,
			direction = uniqueDirections[[did]];
			edgeDirectionIndexMap[Round[direction, epsilon]] = did;
		];
		(* Print[edgeDirectionIndexMap]; *)

		edgeDirectionCellsMatrix = {};

		For[cid = 1, cid <= Length[cells], cid++,
			cell = cells[[cid]] 1.0;
			edgesInCell = Union[ Flatten[Map[getEdgesFromFace, cell], 1], SameTest -> sameCenter];
			edgeDirectionsInCell = getEdgesDirections[edgesInCell];
			edgeDirectionIndexInCell = Union[Map[edgeDirectionIndexMap, Round[edgeDirectionsInCell, epsilon]]];
			(* Print[edgeDirectionIndexInCell]; *)

			edgeDirectionInCell = Table[If[MemberQ[ edgeDirectionIndexInCell, k ], 1, 0], {k, 1, Length[uniqueDirections]}];
			AppendTo[edgeDirectionCellsMatrix, edgeDirectionInCell];
		];

		edgeDirectionCellsMatrix = Transpose[edgeDirectionCellsMatrix];
		Print["edge direction vs cell matrix. Size = "];
		Print[{Length[edgeDirectionCellsMatrix], Length[edgeDirectionCellsMatrix[[1]]]}];
		(* Print[edgeDirectionCellsMatrix]; *)
		rank = MatrixRank[edgeDirectionCellsMatrix, Modulus -> 2];
		Print["Mod 2 rank"];
		Print[rank];

		nullSpace = NullSpace[Transpose[edgeDirectionCellsMatrix], Modulus -> 2];
	];
];

(* 
cell and cell dot product:
Touching a cell A will change the status of all cells B's where the dot product of A and B == certain value. Touching A doesn't change the status of A itself, unless the certain value == 1.

normalized dot product vs matrix rank

5-cell
{-0.25, 4}
{1., 5}

8-cell
{-1., 8}
{0., 4}
{1., 8}

16-cell
{-1., 16}
{-0.5, 8}
{0., 8}
{0.5, 8}
{1., 16}

24-cell
{-1., 24}
{-0.5, 10}
{0., 12}
{0.5, 10}
{1., 24}

120-cell
{-1., 120}
{-0.80901699, 76}
{-0.5, 58}
{-0.30901699, 76}
{0., 44}
{0.30901699, 76}
{0.5, 58}
{0.80901699, 76}
{1., 120}

600-cell
{-1., 600}
{-0.96352549, 538}
{-0.9045085, 520}
{-0.80901699, 326}
{-0.75, 506}
{-0.71352549, 538}
{-0.6545085, 278}
{-0.55901699, 282}
{-0.5, 394}
{-0.4045085, 282}
{-0.3454915, 520}
{-0.30901699, 326}
{-0.25, 506}
{-0.1545085, 282}
{-0.0954915, 278}
{0., 204}
{0.0954915, 278}
{0.1545085, 282}
{0.25, 506}
{0.30901699, 326}
{0.3454915, 520}
{0.4045085, 282}
{0.5, 394}
{0.55901699, 282}
{0.6545085, 278}
{0.71352549, 538}
{0.75, 506}
{0.80901699, 326}
{0.9045085, 520}
{0.96352549, 538}
{1., 600}






====

edge directions:
120-cell: {{20, 60}}
1200 edges are in 60 directions. They are the pairs of the 120 vertices of the 600-cell. There are 20 edges in each direction.
edge rank 44

600-cell: {{12, 60}}
720 edges are in 60 directions. They are the pairs of the 120 vertices of the 600-cell. There are 12 edges in each direction.
edge rank 59

24-cell: {{8, 12}}
96 edges are in 12 directions. They are the pairs of the 24 vertices of the same 24-cell (not dual). There are 8 edges in each direction.
edge rank 5

8-cell: tessaract {{8, 4}}
32 edges are in 4 directions, x, y, z, w directions. They are the pairs of 8 vertices of the 16-cell. There are 8 edges in each direction.
edge rank 4

16-cell: {{2, 12}}
24 edges are in 12 directions. They are the pairs of the 24 vertices of the same 24-cell. There are 2 edges in each direction.
edge rank 4

5-cell: {{1, 10}}
10 edges are in 10 different directions.
edge rank 5

grand 120-cell {5,3,5/2}: {{12, 60}}
As same as 600-cell edges.

 *)
