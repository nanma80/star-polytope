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

shapes = {
	(* "polytope_3_3_3", *)
	(* "polytope_4_3_3", *)
	(* "polytope_3_3_4", *)
	(* "polytope_3_4_3", *)
	(* "polytope_3_4_3_alt" *)
	(* "polytope_5_3_52" *)
	"polytope_5_3_3_cell120"
	(* "polytope_3_3_5_cell600" *)
};


cellCenterRelation = True;
edgeDirectionRelation = False;


dataFolder = "data";
exportToPov = True;
imageFolder = "output";


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
doubleRotationMatrix[theta_] := ArrayFlatten[{{RotationMatrix[-theta], 0}, {0, RotationMatrix[-theta]}}];
getEdgesDirections[edges_] := Module[
	{edgeDirections},
	edgeDirections = Map[#[[1]] - #[[2]] &, edges];
	edgeDirections = Map[If[Dot[randomDirection, #] > 0, 1, -1] * # &, edgeDirections];
	edgeDirections
];

aggrandizeCell[cell_, factor_] := Module[{},
	cellCenter = getCellCenter[cell];
	Map[(# - cellCenter)*factor + cellCenter &, cell, {2}]
];

exportImage[shape_, cells_, explosionFactor_, theta_, serialNumber_] := Module[
	{
		dataFileName,
		shapeTokens,
		color,
		cellShape,
		cellsByLayers,
		layerKeys,
		thickness,
		lighting,
		outputFolder,
		range,
		outputFileName,
		cropCommand,
		inactiveCells,
		inactiveFaces,
		inactiveEdges,
		inactiveVertices,
		activeCells,
		activeFaces,
		touchingIndices,
		notTouchingIndices,
		touchingActiveFaces,
		notTouchingActiveFaces,
		allIndices,
		activeEdges,
		activeVertices,
		graph,
		imageSize,
		faceTemp,faceNormalVector,faceCenter,projectedFaceCenter,faceVisible
	},

	(* If[serialNumber < 30, Continue[]]; *)

	shapeTokens = StringSplit[shape, "_"];
	If[Length[shapeTokens] < 3,
		color = Red,
		cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
		color = allColors[cellShape];
	];

	thickness = Norm[cells[[1]][[1]][[1]]] * 0.008;
	lighting = {{"Point", White, viewPoint * 10}};
	range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

	outputFolder = shape <> "_aggrandize_frames";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "animation_" <> shape <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	imageSize = 240 * {4, 3};
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	activeCells = cells;
	Print["Selected " <> IntegerString[Length[activeCells]] <> " active cells. ExplosionFactor: " <> TextString[explosionFactor]];

	activeCells = Map[explodedCell[#, explosionFactor]&, activeCells];
	activeFaces = Flatten[activeCells, 1];
	(* activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter]; *)
	(* activeVertices = Union[ Flatten[activeFaces,1], SameTest -> sameVertex]; *)
	activeEdges = Flatten[Map[getEdgesFromFace, activeFaces], 1];
	activeVertices = Flatten[activeFaces,1];

	(* range = range /2; *)
	(* projectedActiveFaces = Map[projectTo3d, activeFaces, {2}]; *)
	(* activeCellsCenters = Map[Total[#, 2]/Length[activeCells[[1]]]/Length[activeCells[[1]][[1]]]&, activeCells]; *)
	activeCellsCenters = Map[Total[#, 2]/Total[Map[Length, activeCells[[1]]]]&, activeCells];

	(* activeCellsCenters = Map[projectTo3d, activeCellsCenters]; *)
	(* activeCellsCenters = activeCellsCenters/Norm[activeCellsCenters[[1]]]; *)

    wDistance = Max[Flatten[activeFaces]] * 100000;
    (* Print[wDistance]; *)

	(* fullProjectionMatrix = RotationMatrix[{rootCellCenter, {0, 0, 0, 1}}]; *)
	(* If[shape == "polytope_3_3_5_cell600", fullProjectionMatrix = ArrayFlatten[{{1, 0, 0}, {0, RotationMatrix[-ArcTan[Sqrt[2]]], 0}, {0, 0, 1}}].ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[Pi/4]}}] ]; *)

	fullProjectionMatrix = doubleRotationMatrix[theta];

(* 	perspectiveProjection[activeCellsCenters[[11]], fullProjectionMatrix, wDistance]
	centers = Table[ perspectiveProjection[activeCellsCenters[[k]], fullProjectionMatrix, wDistance], {k, 120}]
	Select[centers, Norm[{#[[1]], #[[2]]}] < 0.01&]
 *)

    projectedActiveFaces = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, activeFaces, {2}];
    range = Max[Flatten[activeFaces]] * 2.3;
    range = Max[Flatten[activeFaces]] * 1.4; (* 120-cell *)
    
    range = 6;
    viewPoint = {50, -50, 50};

    If[shape == "polytope_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 2.2;
    	viewPoint = {1.0, -0.9, 0.5}];
    If[shape == "polytope_3_3_5_cell600", 
    	range = Max[Flatten[activeFaces]] * 1.5;
    	viewPoint = {1.2, -0.7, 0.5}];
    If[shape == "polytope_5_3_3_cell120", 
    	range = Max[Flatten[activeFaces]] * 0.8;
    	viewPoint = {1.2, -0.7, 0.5}];
	If[shape == "bitruncated_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 1.1;
    	viewPoint = {1.2, -0.7, 0.5}];
    Print["range"];
    Print[range];

	rotatedActiveCellsCenters = Map[fullProjectionMatrix.#&, activeCellsCenters];

    (* edges3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, edgeSegments, {2}]; *)
    (* vertices3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, selectedEdgeEnds]; *)
    (* otherVertices3D = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, selectedVertices]; *)

    faceCellRatio = Length[activeFaces]/Length[activeCellsCenters];
    grayArea = 0.05;
    graphElements = {};
    thickness = 0.006;

    graphFaces = {};
    graphEdges = {};

    For[k = 1, k <= Length[activeFaces], k++,
	    cellId = Floor[(k - 1)/faceCellRatio] + 1;
	    color = Red;
	    centerW = cellCenters[[cellId]][[4]]//N;
	    face = projectedActiveFaces[[k]] * (1 + 0.003 * centerW);

		AppendTo[graphFaces,
			{
				Opacity[1],
				color,
				Polygon[ face ]
			}
		];
		edges3d = getEdgesFromFace[face];
		AppendTo[graphEdges,
			{
				FaceForm[White], Map[Cylinder[#, thickness]&, edges3d]
			}
		];
    ];


    Print["draw face count: " <> IntegerString[Length[graphFaces]]];
    Print["draw edge count: " <> IntegerString[Length[graphEdges]]];
    AppendTo[graphElements, graphFaces];
    AppendTo[graphElements, graphEdges];
    (* thickness = 1.0; *)
    (* Print[Map[getHue[mapHopfFibration[#]]&, rotatedActiveCellsCenters]//Tally]; *)

	hopf3dCenters = Map[mapHopfFibration, rotatedActiveCellsCenters];
	(* Print[Map[#[[2]]&, hopf3dCenters//Tally//Sort]//Tally]; *)

	graph = Graphics3D[
		graphElements,
		ViewPoint -> viewPoint * 100,
		ViewVertical -> {0, 0, 1},
		PlotRange -> {{-range, range}, {-range, range}, {-range, range}},
		(* Lighting -> lighting, *)
		Boxed -> False
		(* ViewAngle -> range/Norm[viewPoint]/100/6.7 *)
	];

	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph, ImageSize -> imageSize[[2]]];
	]
	Print["Saved the image to " <> outputFileName];
];

For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	Print[];
	shape = shapes[[shapeIndex]];
	Print[shape];
	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];

	cells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];
	cellCenters = Map[getCellCenter, cells * 1.0];

	cellIds = Range[Length[cellCenters]];
	northCellId = Select[cellIds, cellCenters[[#]][[4]] > 2.6 & ][[1]];

	(* Print["cell centers"]; *)
	(* Map[Print[{#, Round[cellCenters[[#]], epsilon]}]&, cellIds];	 *)

	layer4CellIds = Select[cellIds, Abs[cellCenters[[#]][[4]] - 0.8 ] < 0.1 & ];

	northCellVertices = Union[Flatten[cells[[northCellId]], 1]//N, SameTest -> ApproxSamePoint ];

	randomDirection = {0.01, 0.1, 1, 10.0};
	northCellVertex1 = Sort[northCellVertices, #1.randomDirection > #2.randomDirection &][[1]];
	Print[northCellVertex1];
	selectedLayer4Ids = Sort[layer4CellIds, cellCenters[[#1]].northCellVertex1 > cellCenters[[#2]].northCellVertex1 &][[Range[3]]];

	selectedCellIds = Join[{northCellId}, selectedLayer4Ids];
	Print[selectedCellIds];

	Map[Print[{#, Round[cellCenters[[#]], epsilon]}]&, selectedCellIds];

	constraints = Map[Dot[{x, y, z, w}, cellCenters[[#]]] == Dot[cellCenters[[#]], cellCenters[[#]] ] &, selectedCellIds];
	(* Print[constraint]; *)

	solutions = Solve[Apply[And, constraints], {x, y, z, w}];
	newVertex = {x, y, z, w}/.solutions[[1]];
	Print[newVertex];
	Print[ Map[ApproxSamePoint[#, 0.0] &, newVertex - northCellVertex1 Sqrt[5] ]];
	(* For layer 4, the new vertex is Sqrt[5] times the original vertex *)

	newCells = Map[aggrandizeCell[#, Sqrt[5]]&, cells 1.0];

	Print[newCells//Length];
	Print[newCells[[1]]//Length];
	Print[newCells[[1]][[1]]//Length];
	Print[newCells[[1]][[1]][[1]] ];

	newNorthCellVertices = Union[Flatten[newCells[[northCellId]], 1]//N, SameTest -> ApproxSamePoint ];
	(* Print[newNorthCellVertices]; *)
	(* Intersection[ newNorthCellVertices, {newVertex}, SameTest -> ApproxSamePoint]//Print; *)

	exportImage[shape, newCells, 0, 0, 40];

(* 	faces = Union[ Flatten[newCells * 1.0, 1], SameTest -> sameCenter];
	Print["There are " <> IntegerString[Length[faces]] <> " faces in total."];

	edges = Union[ Flatten[Map[getEdgesFromFace, faces], 1], SameTest -> sameCenter];
	Print["There are " <> IntegerString[Length[edges]] <> " edges in total."];

	vertices = Union[ Flatten[faces,1], SameTest -> ApproxSamePoint];
	Print["There are " <> IntegerString[Length[vertices]] <> " vertices in total."];
 *)


];

(* 
levels: 
2.618: 1
2.118: 12
1.309: 20
0.809: 12
0

 *)
