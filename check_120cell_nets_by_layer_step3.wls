#!/usr/bin/env wolframscript

(*
mogrify -crop 450x450+75+0 -path . pov_*.png
mogrify -crop 300x300+50+0 -path . explode*.gif

magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay 5 -dispose 2 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

(* global config *)

shapes = {
	"test",
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

shapes = {
	(* "polytope_3_4_3", *)
	"polytope_5_3_3_cell120"
	(* "polytope_3_3_5_cell600", *)
	(* "bitruncated_3_4_3" *)
};
(*shape = "test";*)

(* exportToPov = False; *)
exportToPov = True;
dataFolder = "data";
imageFolder = "output";

imageSizes = <|
	(* "allLayers" -> {1000, 750}, (* must be 4:3 *) *)
	"allLayers" -> 240 * {4, 3}, (* must be 4:3 *)
	"singleLayer" -> 150 * {4, 3} (* must be 4:3 *)
|>;

allColors = <|
	"3_3" -> Cyan,
	"5_3" -> Red,
	"3_5" -> Green,
	"52_5" -> Blue,
	"5_52" -> Yellow,
	"52_3" -> Magenta,
	"3_52" -> Orange,
	"3_4" -> Green
|>;

(* shape -> {maxExplosionFactor, frameCount}*)
explosionConfigs = <|
	"polytope_3_4_3" -> {3.0, 150},
	(* 120-cell *)
	"polytope_5_3_3_cell120" -> {1.3, 100},

	(* 600-cell *)
	"polytope_3_3_5_cell600" -> {3.0, 150},

	(* Icosahedral 120-cell. cell: icosahedron *)
	"polytope_3_5_52" -> {2.0, 30},

	(* Small stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron *)
	"polytope_52_5_3" -> {2.0, 30},

	(* Great 120-cell. cell: {5, 5/2}. Great dodecahedron. Self dual *)
	"polytope_5_52_5" -> {2.0, 30},

	(* Grand 120-cell. cell: {5, 3}. Dodecahedron *)
	"polytope_5_3_52" -> {2.0, 30},

	(* Great stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_5" -> {2.0, 30},

	(* Grand stellated 120-cell. cell: {5/2, 5}. Small stellated dodecahedron. Self dual *)
	"polytope_52_5_52" -> {2.0, 30},

	(* Great grand 120-cell. cell: Great dodecahedron *)
	"polytope_5_52_3" -> {2.0, 30},

	(* Greate icosahedral 120-cell. cell: great icosahedron *)
	"polytope_3_52_5" -> {2.0, 30},

	(* Grand 600-cell. cell: tetrahedron, 600 cells *)
	"polytope_3_3_52" -> {2.0, 30},

	(* Great grand stellated 120-cell. cell: great stellated dodecahedron *)
	"polytope_52_3_3" -> {2.0, 30},

	"test" -> {2.0, 3}
|>

rangeFactor = 3.0;
originalProjectionMatrixH4 = {
    {0.00, 0, 2 Sin[2 Pi/15], (1 + Sqrt[5]) Sin[Pi/15]},
    {1, -(1 + Sqrt[5]) Sin[Pi/30], 0, 0.00},
    {1, 3, 4, 1},
    {0, 0, 0, 1}
} * 1.0;

originalProjectionMatrixF4 = {
	{1, 1, Sqrt[3] - 1, 0},
	{1, -1, 0, Sqrt[3] - 1},
    {1, 3, 4, 1},
    {0, 0, 0, 1}
} * 1.0;

roundPrecision = 0.000001;
phi = (1 + Sqrt[5])/2;
viewPoint = {0.75, 1.5, 0.5};
(* viewPoint = {1, -0.5, 0.15}; *)

(* viewPoint = {1.0, 0.0, 0.0}; *)
(* matrix3D = {viewPoint, {0, 1, 0}, {0, 0, 1}}; *)
(* perpViewPoints = Orthogonalize[matrix3D][[2;;3]]; *)
(* rotation3D = RotationMatrix[{{0, 0, 1}, viewPoint}]; *)
(* rotation3D = IdentityMatrix[3]; *)
(* projectionMatrix = rotation3D.Orthogonalize[originalProjectionMatrixH4][[1;;3]]; *)
(* projectionMatrix = rotation3D.Orthogonalize[originalProjectionMatrixF4][[1;;3]]; *)
(* projectionMatrix = rotation3D.IdentityMatrix[4][[1;;3]]; *)

Needs["POVRayRender`"];
ConfigurePOVRayRender["POVRayPath" -> "C:\\Program Files\\POV-Ray\\v3.7\\bin\\pvengine64.exe"];

(* projectTo3d[vertex4d_] := {vertex4d[[1]], vertex4d[[2]], vertex4d[[3]]}; *)
(* projectTo3d[vertex4d_] := projectionMatrix.vertex4d; *)
reflect[point_, mirror_] := FullSimplify[point - 2 * (point.mirror)/(mirror.mirror)*mirror];
doubleReflect[point_, mirror1_, mirror2_] := reflect[reflect[point, mirror1], mirror2];
getEdgesFromFace[face_] := Table[{face[[i+1]], face[[Mod[i+1, Length[face]] + 1]]}, {i, 0, Length[face] - 1}];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
sameVertex[point1_, point2_] := point1 == point2;
sameCenter[edge1_, edge2_] := Total[edge1] == Total[edge2];
sameCellCenter[cell1_, cell2_] := getCellCenter[cell1] == getCellCenter[cell2];
getFaceCenter[face_] := Simplify[Total[face]];
getCellCenter[cell_] := Simplify[Mean[Flatten[cell, 1]]];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
explodedCell[cell_, explosionFactor_] := Map[
	(# + Mean[Map[Mean,cell]]*(Norm[First[First[cell]]//N]/Norm[Mean[Map[Mean,cell]]//N])^1.5 * explosionFactor)&, 
	cell, {2}];
normalizedAngle[u_, v_] := ArcSin[u.v/Norm[u]/Norm[v]]/Pi + 0.5;
projectToDirection[vertex4d_, projectionMatrix_] := vertex4d.Transpose[projectionMatrix];
(* perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]] / (1 + point.(fullProjectionMatrix[[4]])/wDistance); *)
perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]];
normalizedInner[u_, v_] := u.v/Norm[u]/Norm[v];
normalized[u_] := u/Norm[u];
doubleRotationMatrix[theta_, signature_] := ArrayFlatten[{{RotationMatrix[-theta], 0}, {0, RotationMatrix[signature * theta]}}];

getProjectionMatrix[direction_] := Simplify[Orthogonalize[{direction, {2, -1.4, 0.3, 0.9}, {0, 1, 2.3, 0.8}, {0.5, 0.3, 1, 0.1}}]][[2;;4]];

mapHopfFibration[v4d_] := Module[
	{z0, z1},
	z0 = v4d[[1]] + I v4d[[2]];
	z1 = v4d[[3]] + I v4d[[4]];
	x1 = Re[(2 z0 Conjugate[z1])];
	x2 = Im[(2 z0 Conjugate[z1])];
	x3 = Re[z0 Conjugate[z0] - z1 Conjugate[z1]];
	Round[{x1, x2, x3}, roundPrecision]
];

mapHopfFibrationMirror[v4d_] := Module[
	{z0, z1},
	z0 = v4d[[1]] - I v4d[[2]];
	z1 = v4d[[3]] - I v4d[[4]];
	x1 = Re[(2 z0 Conjugate[z1])];
	x2 = Im[(2 z0 Conjugate[z1])];
	x3 = Re[z0 Conjugate[z0] - z1 Conjugate[z1]];
	Round[{x1, x2, x3}, roundPrecision]
];

getHue[v3d_] := If[Norm[v3d[[{1, 2}]]] < 0.001, 
						If[v3d[[3]] > 0, Darker[Blue, 0.8], Lighter[Red, 0.8]],
						(* If[v3d[[3]] > 0,
							Darker[Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1]], 0.3],
							Lighter[Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1]], 0.3]
						] *)
						(* *0.9 to avoid to similar colors of purple *)
						(* Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1] * 0.9] *)
						Hue[Mod[Arg[v3d[[1]] + I v3d[[2]]]/2/Pi , 1]]
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

	shapeTokens = StringSplit[shape, "_"];
	If[Length[shapeTokens] < 3,
		color = Red,
		cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
		color = allColors[cellShape];
	];

	thickness = Norm[cells[[1]][[1]][[1]]] * 0.008;
	lighting = {{"Point", White, viewPoint * 10}};
	range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

	outputFolder = shape <> "_unfold_frames";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "animation_" <> shape <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	imageSize = imageSizes["allLayers"];
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

    wDistance = Max[Flatten[activeFaces]] * 1.05 * 1000000;
    (* Print[wDistance]; *)


	(* fullProjectionMatrix = RotationMatrix[{rootCellCenter, {0, 0, 0, 1}}]; *)
	(* If[shape == "polytope_3_3_5_cell600", fullProjectionMatrix = ArrayFlatten[{{1, 0, 0}, {0, RotationMatrix[-ArcTan[Sqrt[2]]], 0}, {0, 0, 1}}].ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[Pi/4]}}] ]; *)

	fullProjectionMatrix = doubleRotationMatrix[theta, -1];

(* 	perspectiveProjection[activeCellsCenters[[11]], fullProjectionMatrix, wDistance]
	centers = Table[ perspectiveProjection[activeCellsCenters[[k]], fullProjectionMatrix, wDistance], {k, 120}]
	Select[centers, Norm[{#[[1]], #[[2]]}] < 0.01&]
 *)

    projectedActiveFaces = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, activeFaces, {2}];
    range = Max[Flatten[activeFaces]] * 2.3;
    range = Max[Flatten[activeFaces]] * 1.4; (* 120-cell *)

    range = If[negativeFold, 1.3, 6];
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
    thickness = 0.001;

    graphFaces = {};

    For[k = 1, k <= Length[activeFaces], k++,
	    cellId = Floor[(k - 1)/faceCellRatio] + 1;
	    color = cellColors[[cellId]];

		AppendTo[graphFaces,
			{
				Opacity[1],
				color,
				Polygon[ projectedActiveFaces[[k]] ]
			}
		];

    ];


    Print["draw face count: " <> IntegerString[Length[graphFaces]]];
    AppendTo[graphElements, graphFaces];
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

exportAnimation[shape_] := Module[
	{
		outputFolder,
		gifFileName,
		gifFolder,
		explosionConfig,
		maxExplosionFactor,
		frameCount,
		explodeStep,
		explosionFactors,
		frameIndex,
		explosionFactor,
		gifCommand
	},

	outputFolder = shape <> "_unfold_frames";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];
	gifFileName = shape <> "_unfold";
	gifFolder = FileNameJoin[{imageFolder, shape}];
	If[!DirectoryQ[gifFolder], CreateDirectory[gifFolder]];

	explosionConfig = explosionConfigs[shape];
	maxExplosionFactor = explosionConfig[[1]];
	frameCount = explosionConfig[[2]];
	explodeStep = maxExplosionFactor/frameCount;

	frameCount = 200;
	explosionFactor = 2.9 * If[shape == "polytope_3_3_5_cell600", 5, 1];
	explosionFactor = 0.4; (* 120-cell *)
	If[shape == "polytope_3_3_5_cell600", explosionFactor = 0.7];
	If[shape == "polytope_3_4_3", explosionFactor = 0.4];

	angleSpan = Pi/5;
    If[shape == "polytope_3_4_3", 
    	frameCount = 200;
    	angleSpan = 2 Pi/6];
    If[shape == "bitruncated_3_4_3", 
    	frameCount = 200;
    	angleSpan = 2 Pi/6];
    (* frameCount = 20; *)

    thetas = Table[(k - 1) * angleSpan / (frameCount), {k, 1, frameCount}];

    For[ frameIndex = 1, frameIndex <= Length[thetas] , frameIndex++,
        theta = thetas[[frameIndex]] * 1.0;
        Print["Frame #" <> IntegerString[frameIndex] <> "/" <> IntegerString[Length[thetas]] 
            <> " ; theta: " <> ToString[theta, InputForm]];
		exportImage[shape, explosionFactor, theta, frameIndex];
    ];

    delay = If[frameCount > 30, 3, 50];

    (* gifCommand = "magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay "  (* loop back*) *)
    gifCommand = "magick convert -quiet +repage -alpha remove -loop 0 -delay " (* no looping back *)
		<> IntegerString[delay] <> " -dispose 2 " <> outputFolder <> "\\*animation*.png " <> gifFolder <> "\\" <> gifFileName <> ".gif";

	Print[gifCommand];
	Run[gifCommand];
	Print["Saved the animation to " <> gifFolder <> "\\" <> gifFileName <> ".gif"];

    mp4Command = "ffmpeg -i " <> gifFolder <> "\\" <> gifFileName <> ".gif" 
    	<> " -movflags faststart -pix_fmt yuv420p -vf \"scale=trunc(iw/2)*2:trunc(ih/2)*2\" "
    	<> gifFolder <> "\\" <> gifFileName <> ".mp4";

    mp4FileName = gifFolder <> "\\" <> gifFileName <> ".mp4";
    If[FileExistsQ[mp4FileName], DeleteFile[mp4FileName]];
    Print[mp4Command];
    Run[mp4Command];
    Print["Saved the video to " <> gifFolder <> "\\" <> gifFileName <> ".mp4"];
];

(* For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	shape = shapes[[shapeIndex]];	
	If[
		StringContainsQ[shape, "polytope_3_3_"],
		activeLayerMin = 1; activeLayerMax = 15,
		activeLayerMin = 1; activeLayerMax = 9
	];
	If[shape == "polytope_3_4_3", activeLayerMax = 5];
	If[shape == "bitruncated_3_4_3", activeLayerMax = 7];
    
	exportAnimation[shape];
];
 *)

shape = shapes[[1]];

dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
Print["Reading data for " <> shape <> " from " <> dataFileName];
shapeTokens = StringSplit[shape, "_"];
If[Length[shapeTokens] < 3,
	color = Red,
	cellShape = shapeTokens[[2]] <> "_" <> shapeTokens[[3]];
	color = allColors[cellShape];
];

cells = Get[dataFileName];
Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];

epsilon = 0.00000001;
ApproxSamePoint[point1_, point2_] := Round[point1, epsilon] == Round[point2, epsilon];

adjacentCells[c1_,c2_] := Length[Intersection[c1, c2, SameTest -> sameCenter]] == 1;
adjacentCellsIndex[cells_, id1_, id2_] := adjacentCells[cells[[id1]], cells[[id2]]];

sameCenter[set1_, set2_] := ApproxSamePoint[Total[set1], Total[set2]];

buildSchedule[t_, schedule_, level_] := Module[
	{subtrees, subtreeId, newSchedule},
	newSchedule = schedule;
	subtrees = TreeChildren[t];
	For[subtreeId = 1, subtreeId <= Length[subtrees], subtreeId++,
		subtree = subtrees[[subtreeId]];
		subtreeAllData = Map[#[[1]] &, VertexList[TreeGraph[subtree]]];
		newSchedule = Append[newSchedule, {TreeData[t], TreeData[subtree], level, subtreeAllData}];
		newSchedule = buildSchedule[subtree, newSchedule, level + 1];
	];
	newSchedule
];

getRotationSchedule[cells_] := Module[
	{limit, adjMatrix, id1, graph, spanningTree, tree, rootCellCenter, rotationSchedule},
	limit = Length[cells];
	adjMatrix = {};

	For[id1 = 1, id1 <= limit, id1++,
		row = Table[If[adjacentCellsIndex[cells, id1, id2], 1, 0], 
			{id2, 1, limit}];
		Print[id1];
		AppendTo[adjMatrix, row];
	];

	Print[adjMatrix];

	graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
	spanningTree = FindSpanningTree[DirectedGraph[graph]];
	tree = GraphTree[spanningTree];

	rootCellId = TreeData[tree];

	rotationSchedule = {};

	rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
	rotationSchedule
];

rootCellId = 41;
(* rotationSchedule = randomRotationSchedule; *)
(* rotationSchedule = manualRotationSchedule; *)
rotationSchedule = manualRotationSchedule2;

rotation3D = IdentityMatrix[3];
(* for 600 cell, the following will lead to 60 rings. Each ring has 10 cells *)
If[shape == "polytope_5_3_3_cell120" || shape == "polytope_3_3_5_cell600", rotation3D = RotationMatrix[-ArcTan[1/phi], {0, 1, 0}]];
If[shape == "polytope_3_4_3" || shape == "bitruncated_3_4_3", rotation3D = RotationMatrix[Pi/6, {0, 0, 1}].RotationMatrix[-ArcTan[Sqrt[2]], {1, 0, 0}].RotationMatrix[Pi/4, {0, 0, 1}]];

fullProjectionMatrix = ArrayFlatten[
	{{rotation3D, 0}, {0, 1}}
];

(* fullProjectionMatrix = RotationMatrix[{rootCellCenter, {0, 0, 0, 1}}]; *)
(* If[shape == "polytope_3_3_5_cell600", fullProjectionMatrix = ArrayFlatten[{{1, 0, 0}, {0, RotationMatrix[-ArcTan[Sqrt[2]]], 0}, {0, 0, 1}}].ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[Pi/4]}}] ]; *)

cells = Map[#.Transpose[fullProjectionMatrix] &, cells, {2}];
cellCenters = Map[getCellCenter, cells];
cellColors = Map[getHue[mapHopfFibration[#]]&, cellCenters];

(* rootCellCenter = getCellCenter[cells[[rootCellId]]]; *)
(* Print[rootCellCenter//N]; *)
(* Exit[]; *)

maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
(* Print[maxLevel]; *)

foldCells[cells_, rotationSchedule_, foldPercents_] := Module[
	{originalDihedralAngle, rotatedCells, scheduleId, level, schedule, cell1Id, cell2Id, rotatedCellIds},
	originalDihedralAngle = 0;
	rotatedCells = cells;

	For[scheduleId = 1, scheduleId <= Length[rotationSchedule], scheduleId++,
		(* Print["scheduleId " <> IntegerString[scheduleId] <> " out of " <> IntegerString[Length[rotationSchedule]]]; *)
		schedule = rotationSchedule[[scheduleId]];
		level = schedule[[3]];
		If[level >= 1,
			cell1Id = schedule[[1]];
			cell2Id = schedule[[2]];
			rotatedCellIds = schedule[[4]];
			cell1 = rotatedCells[[cell1Id]];
			cell2 = rotatedCells[[cell2Id]];
			pivot = Intersection[cell1, cell2, SameTest -> sameCenter];
			If[Length[pivot] != 1,
				Print["Unexpected error. Cannot find correct pivot"];
				Print[schedule];
				Print[pivot];
				Exit[];
			];

			cellCenter1 = getCellCenter[cell1];
			cellCenter2 = getCellCenter[cell2];
			pivotCenter = Mean[pivot[[1]] ];
			relativeCell1 = cellCenter1 - pivotCenter;
			relativeCell2 = cellCenter2 - pivotCenter;
			
			originalDihedralAngle = ArcCos[ Dot[relativeCell1//N, relativeCell2]/Norm[relativeCell1//N]/Norm[relativeCell2//N] ];
			(* Print[originalDihedralAngle / Pi * 180.]; *)
			grand120CellDihedralAngle = 72/180 * Pi;
			angleToFlat = Pi - originalDihedralAngle;
			angleToStellate = grand120CellDihedralAngle - originalDihedralAngle;
			perc = foldPercents[[level]];
			angleToTarget = If[perc >= 0, angleToFlat, angleToStellate];
			rotMatrix = RotationMatrix[angleToTarget * Abs[perc], {relativeCell2, relativeCell1}];
			For[cid = 1, cid <= Length[rotatedCellIds], cid++,
				cellId = rotatedCellIds[[cid]];
				rotatedCell = rotatedCells[[cellId]];
				rotatedCell = Map[((# - pivotCenter).rotMatrix + pivotCenter)&, rotatedCell, {2}];
				rotatedCells[[cellId]] = rotatedCell;
			];
		];
	];

	allCenters = Map[getCellCenter, rotatedCells];
	selectedCenters = allCenters[[highlightedCellIds]];

	centerAfterFolding = Mean[allCenters[[fixedCells]]];
	shiftedCenters = Map[# - centerAfterFolding &, allCenters];
	shiftedSelectedCenters = shiftedCenters[[highlightedCellIds]];

	layerGroupByAfterFolding = 
	 GroupBy[Range[Length[shiftedSelectedCenters]], 
	  Round[normalized[shiftedSelectedCenters[[#]]][[4]], epsilon] &];
	(* Print["after folding, w-coordinates by layer"]; *)
	(* Print[Sort[Keys[layerGroupByAfterFolding]]]; *)

	layersAfterFolding = Map[If[KeyExistsQ[layerGroupByAfterFolding,#],layerGroupByAfterFolding[#], {}]&, originalDepths];
	layerLengths = Length/@layersAfterFolding;
	(* Print[layerLengths]; *)

	shiftedOtherCenters = shiftedCenters[[otherCells]];
	otherLayerGroupByAfterFolding = 
	 GroupBy[Range[Length[shiftedOtherCenters]], 
	  Round[normalized[shiftedOtherCenters[[#]]][[4]], epsilon] &];

	otherLayersAfterFolding = Map[If[KeyExistsQ[otherLayerGroupByAfterFolding,#],otherLayerGroupByAfterFolding[#], {}]&, originalDepths];
	otherLayerLengths = Length/@otherLayersAfterFolding;
	(* Print[otherLayersAfterFolding]; *)
	Print[otherLayerLengths];
	
	If[KeyExistsQ[layerHistogramMap, otherLayerLengths],
		AppendTo[ layerHistogramMap[otherLayerLengths], compoundId],
		layerHistogramMap[otherLayerLengths] = {compoundId}
	];
	Print[layerHistogramMap];

(* 	If[Length[focusedLayers] == Length[layersAfterFolding],
		Print["layer counts match before and after folding"],
		Print["layer counts do not match before and after folding. Before vs after:"];
		Print[{Length[focusedLayers], Length[layersAfterFolding]}];
	]; *)

	forceQuit = False;
	(* forceQuit = True; *)

	uniqueCenters = Union[selectedCenters, SameTest -> ApproxSamePoint];
	If[Length[uniqueCenters] == Length[highlightedCellIds] || forceQuit,
		Print["Found a good net matching cell count"];
		Print["Element counts: cells, faces, edges, vertices:"];
		Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]];
		Print[rotationSchedule];
		(* Print[FromCharacterCode[{7, 7, 7}]]; *)
		(* Exit[]; *)

(* 		activeFaces = Union[ Flatten[rotatedCells[[highlightedCellIds]], 1], SameTest -> sameCenter ];
		If[Length[activeFaces] == 720 || forceQuit,
			activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter];
			If[Length[activeEdges] == 720 || forceQuit,
				activeVertices = Union[ Flatten[activeFaces,1], SameTest -> ApproxSamePoint];
				If[Length[activeVertices] == 120 || forceQuit,
					Print["Found a good net"];
					Print["Element counts: cells, faces, edges, vertices:"];
					Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]];
					Print[rotationSchedule];
					Exit[];
				];
			];
		]; *)
	];

	If[Length[uniqueCenters] > maxCellCount,
		maxCellCount = Length[uniqueCenters];
		maxCellId = {compoundId},
		If[Length[uniqueCenters] == maxCellCount,
			AppendTo[maxCellId, compoundId];
		];
	];

(* 	If[Length[activeFaces] > maxFaceCount,
		maxFaceCount = Length[activeFaces];
		maxFaceId = {candidateId},
		If[Length[activeFaces] == maxFaceCount,
			AppendTo[maxFaceId, candidateId];
		];
	];

	If[Length[activeEdges] > maxEdgeCount,
		maxEdgeCount = Length[activeEdges];
		maxEdgeId = {candidateId},
		If[Length[activeEdges] == maxEdgeCount,
			AppendTo[maxEdgeId, candidateId];
		];		
	]; *)

	Print["Found a bad net"];
	(* Print["Element counts: cells, faces, edges, vertices:"]; *)
	(* Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]]; *)
	(* Print[{maxCellCount, maxFaceCount, maxEdgeCount, maxCellId, maxFaceId, maxEdgeId}]; *)
	Print[Length[uniqueCenters]];
	Print[{maxCellCount, maxCellId}];	
	(* Print[rotationSchedule]; *)

	

	(* negative fold, random tree {120, 629, 707, 119} *)
	(* negative fold, manual tree {120, 530, 690, 120} *)
	(* negative fold, manual tree2 {120, 544, 696, 120} *)
	(* ideal case: {120, 720, 720, 120} *)
	rotatedCells
];

orientedCellCenters = cellCenters;
orientedCellCentersMap = <||>;
For[cid = 1, cid <= Length[cellCenters], cid++,
  cellCenter = cellCenters[[cid]];
  orientedCellCentersMap[Round[cellCenter, epsilon]] = cid;
  ];

layerGroupBy = 
 GroupBy[Range[Length[orientedCellCenters]], 
  Round[normalized[orientedCellCenters[[#]]][[4]], epsilon] &];
Print["before folding, w-coordinates by layer"];
originalDepths = Sort[Keys[layerGroupBy]];
Print[originalDepths];
layers = Map[If[KeyExistsQ[layerGroupBy,#],layerGroupBy[#], {}]&, originalDepths];
Print[Map[Length, layers]];

layerMap = <||>;

For[layerId = 1, layerId <= Length[layers], layerId++,
  layer = layers[[layerId]];
  For[cid = 1, cid <= Length[layer], cid++,
  	cell = layer[[cid]];
  	layerMap[cell] = layerId;
  ];
];

rotatedCids = 
  Table[orientedCellCentersMap[
    Round[orientedCellCenters[[cid]].RotationMatrix[k 2 Pi/5, {{1, 0, 0, 0}, {0, 1, 0, 0}}], 
     epsilon]], {cid, 1, 120}, {k, 0, 4}];

rotatedCids = Map[Union[Sort[#]]&, rotatedCids];
rotationOrbits = Map[#[[1]] &, Tally[rotatedCids]];

rotationOrbitMap = <||>;
For[orbitId = 1, orbitId <= Length[rotationOrbits], orbitId++,
  orbit = rotationOrbits[[orbitId]];
  For[cid = 1, cid <= Length[orbit], cid++,
  	cell = orbit[[cid]];
  	(* rotationOrbitMap[cell] = rotationOrbits[[orbitId]]; *)
  	rotationOrbitMap[cell] = orbitId;
  ];
];


fixedLayers = { 1, 2, 4, 6, 8, 9 };
fixedCells = Apply[Join, layers[[ fixedLayers ]]];
(* otherLayers = {3, 5, 7}; *)
(* otherLayers = {3}; *)
otherLayers = {3, 7};
(* otherLayers = {5}; *)
otherCells = Apply[Join, layers[[otherLayers]]];

focusedLayers = Join[fixedLayers, otherLayers];

fixedEdges = {};
For[layerId = 2, layerId <= Length[fixedLayers], layerId++,
	layer = fixedLayers[[layerId]];
	innerLayer = fixedLayers[[layerId - 1]];

	For[cellId = 1, cellId <= Length[layers[[layer]]], cellId++,
		fromCell = layers[[layer]][[cellId]];
		For[cellId2 = 1, cellId2 <= Length[layers[[innerLayer]]], cellId2++,
			toCell = layers[[innerLayer]][[cellId2]];
			If[adjacentCellsIndex[cells, fromCell, toCell],
				If[ layer == 9 && (orientedCellCenters[[toCell]][[3]] < 0 || Norm[orientedCellCenters[[toCell]][[{1, 2}]] ] > epsilon),
						Continue[],
					AppendTo[fixedEdges, fromCell \[UndirectedEdge] toCell];
					Break[]
				];
			];
		];
	];
];

getEdgeGroupFromEdge[edge_] := Module[
	{edgeGroup},
	edgeGroup = Table[
		orientedCellCentersMap[
	    	Round[orientedCellCenters[[edge[[1]]]].RotationMatrix[k 2 Pi/5, {{1, 0, 0, 0}, {0, 1, 0, 0}}], 
     		epsilon]] \[UndirectedEdge] 
     	orientedCellCentersMap[
	    	Round[orientedCellCenters[[edge[[2]]]].RotationMatrix[k 2 Pi/5, {{1, 0, 0, 0}, {0, 1, 0, 0}}], 
     		epsilon]], {k, 0, 4}];
     edgeGroup = Map[If[ #[[1]] < #[[2]], #, #[[2]] \[UndirectedEdge] #[[1]] ]&, edgeGroup];
     Sort[edgeGroup]
];

fileNameLayer1 = "candidateStep2_layer_3";
fileNameLayer2 = "candidateStep2_layer_7";

dataLayer1 = Get[FileNameJoin[{dataFolder, "folding_120_cell", fileNameLayer1 <> ".wl"}]];
dataLayer2 = Get[FileNameJoin[{dataFolder, "folding_120_cell", fileNameLayer2 <> ".wl"}]];

candidateIds1 = Keys[dataLayer1];
candidateIds2 = Keys[dataLayer2];

fixedLayerLengths = {1, 12, 0, 12, 0, 12, 0, 12, 1};
completeLengths = {1, 12, 20, 12, 30, 12, 20, 12, 1};

exportData = <||>;
resultCount = 0;

maxCellCount = -1;
maxFaceCount = -1;
maxEdgeCount = -1;
maxCellId = {};
maxFaceId = {};
maxEdgeId = {};
layerHistogramMap = <||>;



For[id1 = 1, id1 <= Length[candidateIds1], id1++,
	candidateId1 = candidateIds1[[id1]];
	data1 = dataLayer1[candidateId1];
	edgeGroups1 = data1[[1]];
	centers1 = data1[[2]];
	layerLengths1 = data1[[3]];

	For[id2 = 1, id2 <= Length[candidateIds2], id2++,
		candidateId2 = candidateIds2[[id2]];
		data2 = dataLayer2[candidateId2];
		edgeGroups2 = data2[[1]];
		centers2 = data2[[2]];
		layerLengths2 = data2[[3]];

		compoundId = Join[candidateId1, candidateId2];
		compoundLayerLengths = layerLengths1 + layerLengths2;
		(* Print[]; *)
		(* Print[compoundLayerLengths]; *)
		totalLengths = fixedLayerLengths + compoundLayerLengths;
		If[ Min[completeLengths - totalLengths] < 0,
			(* Print["length violation"]; *)
			(* Print[totalLengths]; *)
			Continue[];
		];

		compoundEdgeGroups = Join[edgeGroups1, edgeGroups2];
		intCenters = Intersection[centers1, centers2];
		(* Print[intCenters//Length]; *)
		If[ Length[intCenters] > 0,
			(* Print["center overlap violation"]; *)
			(* Print[Length[intCenters]]; *)
			Continue[];
		];

		Print["Passing quick filtering:"];
		Print[{id1, id2}];

		joinCenters = Join[centers1, centers2];

		combinedGraph = Graph[Join[Apply[Join, compoundEdgeGroups], fixedEdges]];

		If[ConnectedGraphQ[combinedGraph] == False, 
			Print["Unexpected: Graph is not connected. Skip"];
			Exit[];
		];

		If[TreeGraphQ[combinedGraph] == False,
			Print["Unexpected: combined graph is not a tree"];
			Exit[];
		];

		highlightedCellIds = VertexList[combinedGraph]//Sort;
		Print[highlightedCellIds//Length];

		combinedTree = GraphTree[combinedGraph, 41];
		rotationSchedule = {};
		rotationSchedule = buildSchedule[combinedTree, rotationSchedule, 1];
		maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
		foldPercents = Table[-1, {k, maxLevel}];
		rotatedCells = foldCells[cells, rotationSchedule, foldPercents];

		shiftedOtherCentersRounded = Round[shiftedOtherCenters, epsilon];

		If[otherLayerLengths != compoundLayerLengths,
			Print["Unexpected: computed layer lengths don't match with derived layer lengths"];
			Print[otherLayerLengths];
			Print[compoundLayerLengths];
			Exit[];
		];

		If[Length[shiftedOtherCentersRounded] != Length[joinCenters],
			Print["Unexpected: shiftedOtherCentersRounded doesn't match joinCenters by length"];
			Print[Length[shiftedOtherCentersRounded]];
			Print[Length[joinCenters]];
			Exit[];
		];

		If[Length[Intersection[shiftedOtherCentersRounded, joinCenters]] != Length[joinCenters],
			Print["Unexpected: shiftedOtherCentersRounded doesn't match joinCenters in coordinates"];
			Print[Length[Intersection[shiftedOtherCentersRounded, joinCenters]]];
			Print[Length[joinCenters]];
			Exit[];
		];

		Print["passing all checks"];

		exportData[ compoundId ] = {
			compoundEdgeGroups,
			shiftedOtherCentersRounded,
			otherLayerLengths
		};

		resultCount++;
		(* If[resultCount > 10, Exit[]]; *)

	];
];

fileName = "candidateStep3_layer_37";

exportDataFileName = FileNameJoin[{dataFolder, "folding_120_cell", fileName <> ".wl"}];

If[FileExistsQ[exportDataFileName], DeleteFile[exportDataFileName]];
Save[exportDataFileName, exportData];












Exit[];


(* 
{
{{0, 0, 5, 0, 30, 0, 5, 0, 0}, 448}, 
{{0, 0, 10, 0, 25, 0, 5, 0, 0}, 488}, 
{{0, 0, 5, 0, 25, 0, 10, 0, 0}, 488}, 

{{0, 0, 10, 0, 20, 0, 10, 0, 0}, 268}, 

{{0, 0, 0, 0, 30, 0, 10, 0, 0}, 80}
{{0, 0, 10, 0, 30, 0, 0, 0, 0}, 80}, 

}


<|{0, 0, 5, 0, 30, 0, 5, 0, 0} -> {{11528, 5023}, {11528, 6172}, {11528, 6616}, {11528, 10548}, {11528, 11697}, {11528, 12141}, {11531, 5023}, {11531, 6172}, {11531, 6616}, {11531, 10548}, {11531, 11697}, {11531, 12141}, {11534, 5017}, {11534, 5018}, {11534, 6166}, {11534, 6167}, {11534, 6532}, {11534, 6533}, {11534, 6610}, {11534, 6611}, {11534, 10542}, {11534, 10543}, {11534, 11691}, {11534, 11692}, {11534, 12057}, {11534, 12058}, {11534, 12135}, {11534, 12136}, {11595, 4963}, {11595, 4964}, {11595, 5613}, {11595, 5614}, {11595, 5706}, {11595, 5707}, {11595, 10488}, {11595, 10489}, {11595, 11138}, {11595, 11139}, {11595, 11231}, {11595, 11232}, {11605, 5023}, {11605, 6172}, {11605, 6616}, {11605, 10548}, {11605, 11697}, {11605, 12141}, {11608, 5023}, {11608, 6172}, {11608, 6616}, {11608, 10548}, {11608, 11697}, {11608, 12141}, {11798, 5006}, {11798, 5808}, {11798, 5916}, {11798, 10531}, {11798, 11333}, {11798, 11441}, {11801, 5006}, {11801, 5808}, {11801, 5916}, {11801, 10531}, {11801, 11333}, {11801, 11441}, {11804, 5000}, {11804, 5001}, {11804, 5802}, {11804, 5803}, {11804, 5910}, {11804, 5911}, {11804, 6515}, {11804, 6516}, {11804, 10525}, {11804, 10526}, {11804, 11327}, {11804, 11328}, {11804, 11435}, {11804, 11436}, {11804, 12040}, {11804, 12041}, {11853, 5006}, {11853, 5808}, {11853, 5916}, {11853, 10531}, {11853, 11333}, {11853, 11441}, {11856, 5006}, {11856, 5808}, {11856, 5916}, {11856, 10531}, {11856, 11333}, {11856, 11441}, {11859, 5000}, {11859, 5001}, {11859, 5802}, {11859, 5803}, {11859, 5910}, {11859, 5911}, {11859, 6515}, {11859, 6516}, {11859, 10525}, {11859, 10526}, {11859, 11327}, {11859, 11328}, {11859, 11435}, {11859, 11436}, {11859, 12040}, {11859, 12041}, {11868, 6015}, {11868, 6149}, {11868, 11540}, {11868, 11674}, {11871, 6015}, {11871, 6149}, {11871, 11540}, {11871, 11674}, {11928, 5023}, {11928, 6172}, {11928, 6616}, {11928, 10548}, {11928, 11697}, {11928, 12141}, {11931, 5023}, {11931, 6172}, {11931, 6616}, {11931, 10548}, {11931, 11697}, {11931, 12141}, {11934, 5017}, {11934, 5018}, {11934, 6166}, {11934, 6167}, {11934, 6532}, {11934, 6533}, {11934, 6610}, {11934, 6611}, {11934, 10542}, {11934, 10543}, {11934, 11691}, {11934, 11692}, {11934, 12057}, {11934, 12058}, {11934, 12135}, {11934, 12136}, {11973, 6015}, {11973, 6149}, {11973, 11540}, {11973, 11674}, {11976, 6015}, {11976, 6149}, {11976, 11540}, {11976, 11674}, {12017, 4963}, {12017, 4964}, {12017, 5613}, {12017, 5614}, {12017, 5706}, {12017, 5707}, {12017, 10488}, {12017, 10489}, {12017, 11138}, {12017, 11139}, {12017, 11231}, {12017, 11232}, {12057, 5006}, {12057, 5808}, {12057, 5916}, {12057, 10531}, {12057, 11333}, {12057, 11441}, {12060, 5006}, {12060, 5808}, {12060, 5916}, {12060, 10531}, {12060, 11333}, {12060, 11441}, {15167, 19332}, {15167, 19776}, {15170, 19332}, {15170, 19776}, {15173, 19326}, {15173, 19327}, {15173, 19692}, {15173, 19693}, {15173, 19770}, {15173, 19771}, {15197, 18968}, {15197, 19076}, {15200, 18968}, {15200, 19076}, {15203, 18962}, {15203, 18963}, {15203, 19070}, {15203, 19071}, {15203, 19675}, {15203, 19676}, {15212, 19175}, {15212, 19309}, {15215, 19175}, {15215, 19309}, {15852, 19332}, {15852, 19776}, {15855, 19332}, {15855, 19776}, {15858, 19326}, {15858, 19327}, {15858, 19692}, {15858, 19693}, {15858, 19770}, {15858, 19771}, {15919, 18773}, {15919, 18774}, {15919, 18866}, {15919, 18867}, {15929, 19332}, {15929, 19776}, {15932, 19332}, {15932, 19776}, {15973, 17706}, {15973, 17825}, {15976, 17706}, {15976, 17825}, {15979, 17700}, {15979, 17701}, {15979, 17819}, {15979, 17820}, {15988, 17706}, {15988, 17825}, {15991, 17706}, {15991, 17825}, {15994, 17700}, {15994, 17701}, {15994, 17819}, {15994, 17820}, {16025, 17376}, {16025, 17377}, {16055, 17359}, {16055, 17360}, {16065, 17706}, {16065, 17825}, {16068, 17706}, {16068, 17825}, {16122, 18968}, {16122, 19076}, {16125, 18968}, {16125, 19076}, {16128, 18962}, {16128, 18963}, {16128, 19070}, {16128, 19071}, {16128, 19675}, {16128, 19676}, {16177, 18968}, {16177, 19076}, {16180, 18968}, {16180, 19076}, {16183, 18962}, {16183, 18963}, {16183, 19070}, {16183, 19071}, {16183, 19675}, {16183, 19676}, {16192, 19175}, {16192, 19309}, {16195, 19175}, {16195, 19309}, {16252, 19332}, {16252, 19776}, {16255, 19332}, {16255, 19776}, {16258, 19326}, {16258, 19327}, {16258, 19692}, {16258, 19693}, {16258, 19770}, {16258, 19771}, {16297, 19175}, {16297, 19309}, {16300, 19175}, {16300, 19309}, {16341, 18773}, {16341, 18774}, {16341, 18866}, {16341, 18867}, {16381, 18968}, {16381, 19076}, {16384, 18968}, {16384, 19076}, {16938, 19332}, {16938, 19776}, {16941, 19332}, {16941, 19776}, {16944, 19326}, {16944, 19327}, {16944, 19692}, {16944, 19693}, {16944, 19770}, {16944, 19771}, {16968, 18968}, {16968, 19076}, {16971, 18968}, {16971, 19076}, {16974, 18962}, {16974, 18963}, {16974, 19070}, {16974, 19071}, {16974, 19675}, {16974, 19676}, {16983, 19175}, {16983, 19309}, {16986, 19175}, {16986, 19309}, {17623, 19332}, {17623, 19776}, {17626, 19332}, {17626, 19776}, {17629, 19326}, {17629, 19327}, {17629, 19692}, {17629, 19693}, {17629, 19770}, {17629, 19771}, {17690, 18773}, {17690, 18774}, {17690, 18866}, {17690, 18867}, {17700, 19332}, {17700, 19776}, {17703, 19332}, {17703, 19776}, {17744, 17706}, {17744, 17825}, {17747, 17706}, {17747, 17825}, {17750, 17700}, {17750, 17701}, {17750, 17819}, {17750, 17820}, {17759, 17706}, {17759, 17825}, {17762, 17706}, {17762, 17825}, {17765, 17700}, {17765, 17701}, {17765, 17819}, {17765, 17820}, {17796, 17376}, {17796, 17377}, {17826, 17359}, {17826, 17360}, {17836, 17706}, {17836, 17825}, {17839, 17706}, {17839, 17825}, {17893, 18968}, {17893, 19076}, {17896, 18968}, {17896, 19076}, {17899, 18962}, {17899, 18963}, {17899, 19070}, {17899, 19071}, {17899, 19675}, {17899, 19676}, {17948, 18968}, {17948, 19076}, {17951, 18968}, {17951, 19076}, {17954, 18962}, {17954, 18963}, {17954, 19070}, {17954, 19071}, {17954, 19675}, {17954, 19676}, {17963, 19175}, {17963, 19309}, {17966, 19175}, {17966, 19309}, {18023, 19332}, {18023, 19776}, {18026, 19332}, {18026, 19776}, {18029, 19326}, {18029, 19327}, {18029, 19692}, {18029, 19693}, {18029, 19770}, {18029, 19771}, {18068, 19175}, {18068, 19309}, {18071, 19175}, {18071, 19309}, {18112, 18773}, {18112, 18774}, {18112, 18866}, {18112, 18867}, {18152, 18968}, {18152, 19076}, {18155, 18968}, {18155, 19076}, {19232, 5925}, {19232, 6608}, {19232, 11450}, {19232, 12133}, {19235, 5925}, {19235, 6608}, {19235, 11450}, {19235, 12133}, {19238, 5919}, {19238, 5920}, {19238, 6524}, {19238, 6525}, {19238, 6602}, {19238, 6603}, {19238, 11444}, {19238, 11445}, {19238, 12049}, {19238, 12050}, {19238, 12127}, {19238, 12128}, {19247, 6150}, {19247, 11675}, {19250, 6150}, {19250, 11675}, {19654, 5925}, {19654, 6608}, {19654, 11450}, {19654, 12133}, {19657, 5925}, {19657, 6608}, {19657, 11450}, {19657, 12133}, {19660, 5919}, {19660, 5920}, {19660, 6524}, {19660, 6525}, {19660, 6602}, {19660, 6603}, {19660, 11444}, {19660, 11445}, {19660, 12049}, {19660, 12050}, {19660, 12127}, {19660, 12128}, {19699, 6014}, {19699, 11539}, {19702, 6014}, {19702, 11539}}, {0, 0, 10, 0, 25, 0, 5, 0, 0} -> {{11528, 5081}, {11528, 6146}, {11528, 10513}, {11528, 11671}, {11528, 18236}, {11531, 5081}, {11531, 6146}, {11531, 10513}, {11531, 11671}, {11531, 18236}, {11534, 5062}, {11534, 5063}, {11534, 5075}, {11534, 5076}, {11534, 5864}, {11534, 6146}, {11534, 6483}, {11534, 10507}, {11534, 10508}, {11534, 10587}, {11534, 10588}, {11534, 11389}, {11534, 11671}, {11534, 12008}, {11534, 18230}, {11534, 18231}, {11595, 5062}, {11595, 5063}, {11595, 5075}, {11595, 5076}, {11595, 5081}, {11595, 5864}, {11595, 6483}, {11595, 10507}, {11595, 10508}, {11595, 10513}, {11595, 10587}, {11595, 10588}, {11595, 11389}, {11595, 12008}, {11605, 5081}, {11605, 6146}, {11605, 10513}, {11605, 11671}, {11605, 18236}, {11608, 5081}, {11608, 6146}, {11608, 10513}, {11608, 11671}, {11608, 18236}, {11798, 5081}, {11798, 5794}, {11798, 10513}, {11798, 11319}, {11798, 17536}, {11801, 5081}, {11801, 5794}, {11801, 10513}, {11801, 11319}, {11801, 17536}, {11804, 5062}, {11804, 5063}, {11804, 5075}, {11804, 5076}, {11804, 5794}, {11804, 5864}, {11804, 6483}, {11804, 10507}, {11804, 10508}, {11804, 10587}, {11804, 10588}, {11804, 11319}, {11804, 11389}, {11804, 12008}, {11804, 17530}, {11804, 17531}, {11853, 5081}, {11853, 5794}, {11853, 10513}, {11853, 11319}, {11853, 17536}, {11856, 5081}, {11856, 5794}, {11856, 10513}, {11856, 11319}, {11856, 17536}, {11859, 5062}, {11859, 5063}, {11859, 5075}, {11859, 5076}, {11859, 5794}, {11859, 5864}, {11859, 6483}, {11859, 10507}, {11859, 10508}, {11859, 10587}, {11859, 10588}, {11859, 11319}, {11859, 11389}, {11859, 12008}, {11859, 17530}, {11859, 17531}, {11868, 5794}, {11868, 6146}, {11868, 11319}, {11868, 11671}, {11868, 17635}, {11868, 17769}, {11871, 5794}, {11871, 6146}, {11871, 11319}, {11871, 11671}, {11871, 17635}, {11871, 17769}, {11928, 5081}, {11928, 6146}, {11928, 10513}, {11928, 11671}, {11928, 18236}, {11931, 5081}, {11931, 6146}, {11931, 10513}, {11931, 11671}, {11931, 18236}, {11934, 5062}, {11934, 5063}, {11934, 5075}, {11934, 5076}, {11934, 5864}, {11934, 6146}, {11934, 6483}, {11934, 10507}, {11934, 10508}, {11934, 10587}, {11934, 10588}, {11934, 11389}, {11934, 11671}, {11934, 12008}, {11934, 18230}, {11934, 18231}, {11973, 5794}, {11973, 6146}, {11973, 11319}, {11973, 11671}, {11973, 17635}, {11973, 17769}, {11976, 5794}, {11976, 6146}, {11976, 11319}, {11976, 11671}, {11976, 17635}, {11976, 17769}, {12017, 5062}, {12017, 5063}, {12017, 5075}, {12017, 5076}, {12017, 5081}, {12017, 5864}, {12017, 6483}, {12017, 10507}, {12017, 10508}, {12017, 10513}, {12017, 10587}, {12017, 10588}, {12017, 11389}, {12017, 12008}, {12057, 5081}, {12057, 5794}, {12057, 10513}, {12057, 11319}, {12057, 17536}, {12060, 5081}, {12060, 5794}, {12060, 10513}, {12060, 11319}, {12060, 17536}, {15167, 18236}, {15167, 19306}, {15170, 18236}, {15170, 19306}, {15173, 18230}, {15173, 18231}, {15173, 19024}, {15173, 19306}, {15173, 19643}, {15197, 17536}, {15197, 18954}, {15200, 17536}, {15200, 18954}, {15203, 17530}, {15203, 17531}, {15203, 18954}, {15203, 19024}, {15203, 19643}, {15212, 17635}, {15212, 17769}, {15212, 18954}, {15212, 19306}, {15215, 17635}, {15215, 17769}, {15215, 18954}, {15215, 19306}, {15852, 18236}, {15852, 19306}, {15855, 18236}, {15855, 19306}, {15858, 18230}, {15858, 18231}, {15858, 19024}, {15858, 19306}, {15858, 19643}, {15919, 19024}, {15919, 19643}, {15929, 18236}, {15929, 19306}, {15932, 18236}, {15932, 19306}, {15973, 17536}, {15973, 17635}, {15973, 17769}, {15973, 18236}, {15976, 17536}, {15976, 17635}, {15976, 17769}, {15976, 18236}, {15979, 17530}, {15979, 17531}, {15979, 17635}, {15979, 17769}, {15979, 18230}, {15979, 18231}, {15988, 17536}, {15988, 17635}, {15988, 17769}, {15988, 18236}, {15991, 17536}, {15991, 17635}, {15991, 17769}, {15991, 18236}, {15994, 17530}, {15994, 17531}, {15994, 17635}, {15994, 17769}, {15994, 18230}, {15994, 18231}, {16025, 18230}, {16025, 18231}, {16025, 18236}, {16055, 17530}, {16055, 17531}, {16055, 17536}, {16065, 17536}, {16065, 17635}, {16065, 17769}, {16065, 18236}, {16068, 17536}, {16068, 17635}, {16068, 17769}, {16068, 18236}, {16122, 17536}, {16122, 18954}, {16125, 17536}, {16125, 18954}, {16128, 17530}, {16128, 17531}, {16128, 18954}, {16128, 19024}, {16128, 19643}, {16177, 17536}, {16177, 18954}, {16180, 17536}, {16180, 18954}, {16183, 17530}, {16183, 17531}, {16183, 18954}, {16183, 19024}, {16183, 19643}, {16192, 17635}, {16192, 17769}, {16192, 18954}, {16192, 19306}, {16195, 17635}, {16195, 17769}, {16195, 18954}, {16195, 19306}, {16252, 18236}, {16252, 19306}, {16255, 18236}, {16255, 19306}, {16258, 18230}, {16258, 18231}, {16258, 19024}, {16258, 19306}, {16258, 19643}, {16297, 17635}, {16297, 17769}, {16297, 18954}, {16297, 19306}, {16300, 17635}, {16300, 17769}, {16300, 18954}, {16300, 19306}, {16341, 19024}, {16341, 19643}, {16381, 17536}, {16381, 18954}, {16384, 17536}, {16384, 18954}, {16938, 18236}, {16938, 19306}, {16941, 18236}, {16941, 19306}, {16944, 18230}, {16944, 18231}, {16944, 19024}, {16944, 19306}, {16944, 19643}, {16968, 17536}, {16968, 18954}, {16971, 17536}, {16971, 18954}, {16974, 17530}, {16974, 17531}, {16974, 18954}, {16974, 19024}, {16974, 19643}, {16983, 17635}, {16983, 17769}, {16983, 18954}, {16983, 19306}, {16986, 17635}, {16986, 17769}, {16986, 18954}, {16986, 19306}, {17623, 18236}, {17623, 19306}, {17626, 18236}, {17626, 19306}, {17629, 18230}, {17629, 18231}, {17629, 19024}, {17629, 19306}, {17629, 19643}, {17690, 19024}, {17690, 19643}, {17700, 18236}, {17700, 19306}, {17703, 18236}, {17703, 19306}, {17744, 17536}, {17744, 17635}, {17744, 17769}, {17744, 18236}, {17747, 17536}, {17747, 17635}, {17747, 17769}, {17747, 18236}, {17750, 17530}, {17750, 17531}, {17750, 17635}, {17750, 17769}, {17750, 18230}, {17750, 18231}, {17759, 17536}, {17759, 17635}, {17759, 17769}, {17759, 18236}, {17762, 17536}, {17762, 17635}, {17762, 17769}, {17762, 18236}, {17765, 17530}, {17765, 17531}, {17765, 17635}, {17765, 17769}, {17765, 18230}, {17765, 18231}, {17796, 18230}, {17796, 18231}, {17796, 18236}, {17826, 17530}, {17826, 17531}, {17826, 17536}, {17836, 17536}, {17836, 17635}, {17836, 17769}, {17836, 18236}, {17839, 17536}, {17839, 17635}, {17839, 17769}, {17839, 18236}, {17893, 17536}, {17893, 18954}, {17896, 17536}, {17896, 18954}, {17899, 17530}, {17899, 17531}, {17899, 18954}, {17899, 19024}, {17899, 19643}, {17948, 17536}, {17948, 18954}, {17951, 17536}, {17951, 18954}, {17954, 17530}, {17954, 17531}, {17954, 18954}, {17954, 19024}, {17954, 19643}, {17963, 17635}, {17963, 17769}, {17963, 18954}, {17963, 19306}, {17966, 17635}, {17966, 17769}, {17966, 18954}, {17966, 19306}, {18023, 18236}, {18023, 19306}, {18026, 18236}, {18026, 19306}, {18029, 18230}, {18029, 18231}, {18029, 19024}, {18029, 19306}, {18029, 19643}, {18068, 17635}, {18068, 17769}, {18068, 18954}, {18068, 19306}, {18071, 17635}, {18071, 17769}, {18071, 18954}, {18071, 19306}, {18112, 19024}, {18112, 19643}, {18152, 17536}, {18152, 18954}, {18155, 17536}, {18155, 18954}, {19232, 5081}, {19232, 10513}, {19235, 5081}, {19235, 10513}, {19238, 5062}, {19238, 5063}, {19238, 5075}, {19238, 5076}, {19238, 5864}, {19238, 6483}, {19238, 10507}, {19238, 10508}, {19238, 10587}, {19238, 10588}, {19238, 11389}, {19238, 12008}, {19238, 19024}, {19238, 19643}, {19247, 6146}, {19247, 11671}, {19247, 19306}, {19250, 6146}, {19250, 11671}, {19250, 19306}, {19654, 5081}, {19654, 10513}, {19657, 5081}, {19657, 10513}, {19660, 5062}, {19660, 5063}, {19660, 5075}, {19660, 5076}, {19660, 5864}, {19660, 6483}, {19660, 10507}, {19660, 10508}, {19660, 10587}, {19660, 10588}, {19660, 11389}, {19660, 12008}, {19660, 19024}, {19660, 19643}, {19699, 5794}, {19699, 11319}, {19699, 18954}, {19702, 5794}, {19702, 11319}, {19702, 18954}}, {0, 0, 10, 0, 30, 0, 0, 0, 0} -> {{11597, 5081}, {11597, 10513}, {11600, 5081}, {11600, 10513}, {11603, 5062}, {11603, 5063}, {11603, 5075}, {11603, 5076}, {11603, 5864}, {11603, 6483}, {11603, 10507}, {11603, 10508}, {11603, 10587}, {11603, 10588}, {11603, 11389}, {11603, 12008}, {11612, 6146}, {11612, 11671}, {11615, 6146}, {11615, 11671}, {12019, 5081}, {12019, 10513}, {12022, 5081}, {12022, 10513}, {12025, 5062}, {12025, 5063}, {12025, 5075}, {12025, 5076}, {12025, 5864}, {12025, 6483}, {12025, 10507}, {12025, 10508}, {12025, 10587}, {12025, 10588}, {12025, 11389}, {12025, 12008}, {12064, 5794}, {12064, 11319}, {12067, 5794}, {12067, 11319}, {15927, 19024}, {15927, 19643}, {15936, 19306}, {15939, 19306}, {16027, 18236}, {16030, 18236}, {16033, 18230}, {16033, 18231}, {16057, 17536}, {16060, 17536}, {16063, 17530}, {16063, 17531}, {16072, 17635}, {16072, 17769}, {16075, 17635}, {16075, 17769}, {16349, 19024}, {16349, 19643}, {16388, 18954}, {16391, 18954}, {17698, 19024}, {17698, 19643}, {17707, 19306}, {17710, 19306}, {17798, 18236}, {17801, 18236}, {17804, 18230}, {17804, 18231}, {17828, 17536}, {17831, 17536}, {17834, 17530}, {17834, 17531}, {17843, 17635}, {17843, 17769}, {17846, 17635}, {17846, 17769}, {18120, 19024}, {18120, 19643}, {18159, 18954}, {18162, 18954}}, {0, 0, 5, 0, 25, 0, 10, 0, 0} -> {{11851, 4963}, {11851, 4964}, {11851, 5000}, {11851, 5001}, {11851, 5006}, {11851, 5613}, {11851, 5614}, {11851, 5706}, {11851, 5707}, {11851, 5802}, {11851, 5803}, {11851, 5808}, {11851, 5910}, {11851, 5911}, {11851, 5916}, {11851, 6515}, {11851, 6516}, {11851, 10488}, {11851, 10489}, {11851, 10525}, {11851, 10526}, {11851, 10531}, {11851, 11138}, {11851, 11139}, {11851, 11231}, {11851, 11232}, {11851, 11327}, {11851, 11328}, {11851, 11333}, {11851, 11435}, {11851, 11436}, {11851, 11441}, {11851, 12040}, {11851, 12041}, {11851, 17359}, {11851, 17360}, {11864, 5006}, {11864, 5023}, {11864, 5808}, {11864, 5916}, {11864, 6015}, {11864, 6149}, {11864, 6172}, {11864, 6616}, {11864, 10531}, {11864, 10548}, {11864, 11333}, {11864, 11441}, {11864, 11540}, {11864, 11674}, {11864, 11697}, {11864, 12141}, {11864, 17706}, {11864, 17825}, {11926, 4963}, {11926, 4964}, {11926, 5017}, {11926, 5018}, {11926, 5023}, {11926, 5613}, {11926, 5614}, {11926, 5706}, {11926, 5707}, {11926, 6166}, {11926, 6167}, {11926, 6172}, {11926, 6532}, {11926, 6533}, {11926, 6610}, {11926, 6611}, {11926, 6616}, {11926, 10488}, {11926, 10489}, {11926, 10542}, {11926, 10543}, {11926, 10548}, {11926, 11138}, {11926, 11139}, {11926, 11231}, {11926, 11232}, {11926, 11691}, {11926, 11692}, {11926, 11697}, {11926, 12057}, {11926, 12058}, {11926, 12135}, {11926, 12136}, {11926, 12141}, {11926, 17376}, {11926, 17377}, {11966, 5006}, {11966, 5023}, {11966, 5808}, {11966, 5916}, {11966, 6015}, {11966, 6149}, {11966, 6172}, {11966, 6616}, {11966, 10531}, {11966, 10548}, {11966, 11333}, {11966, 11441}, {11966, 11540}, {11966, 11674}, {11966, 11697}, {11966, 12141}, {11966, 17706}, {11966, 17825}, {15128, 17706}, {15128, 17825}, {15128, 18968}, {15128, 19076}, {15128, 19175}, {15128, 19309}, {15128, 19332}, {15128, 19776}, {15131, 17706}, {15131, 17825}, {15131, 18968}, {15131, 19076}, {15131, 19175}, {15131, 19309}, {15131, 19332}, {15131, 19776}, {15134, 17700}, {15134, 17701}, {15134, 17819}, {15134, 17820}, {15134, 18962}, {15134, 18963}, {15134, 19070}, {15134, 19071}, {15134, 19175}, {15134, 19309}, {15134, 19326}, {15134, 19327}, {15134, 19675}, {15134, 19676}, {15134, 19692}, {15134, 19693}, {15134, 19770}, {15134, 19771}, {15205, 17706}, {15205, 17825}, {15205, 18968}, {15205, 19076}, {15205, 19175}, {15205, 19309}, {15205, 19332}, {15205, 19776}, {15208, 17706}, {15208, 17825}, {15208, 18968}, {15208, 19076}, {15208, 19175}, {15208, 19309}, {15208, 19332}, {15208, 19776}, {16175, 17359}, {16175, 17360}, {16175, 18773}, {16175, 18774}, {16175, 18866}, {16175, 18867}, {16175, 18962}, {16175, 18963}, {16175, 18968}, {16175, 19070}, {16175, 19071}, {16175, 19076}, {16175, 19675}, {16175, 19676}, {16188, 17706}, {16188, 17825}, {16188, 18968}, {16188, 19076}, {16188, 19175}, {16188, 19309}, {16188, 19332}, {16188, 19776}, {16250, 17376}, {16250, 17377}, {16250, 18773}, {16250, 18774}, {16250, 18866}, {16250, 18867}, {16250, 19326}, {16250, 19327}, {16250, 19332}, {16250, 19692}, {16250, 19693}, {16250, 19770}, {16250, 19771}, {16250, 19776}, {16290, 17706}, {16290, 17825}, {16290, 18968}, {16290, 19076}, {16290, 19175}, {16290, 19309}, {16290, 19332}, {16290, 19776}, {16884, 17706}, {16884, 17825}, {16884, 18968}, {16884, 19076}, {16884, 19175}, {16884, 19309}, {16884, 19332}, {16884, 19776}, {16887, 17706}, {16887, 17825}, {16887, 18968}, {16887, 19076}, {16887, 19175}, {16887, 19309}, {16887, 19332}, {16887, 19776}, {16890, 17700}, {16890, 17701}, {16890, 17819}, {16890, 17820}, {16890, 18962}, {16890, 18963}, {16890, 19070}, {16890, 19071}, {16890, 19175}, {16890, 19309}, {16890, 19326}, {16890, 19327}, {16890, 19675}, {16890, 19676}, {16890, 19692}, {16890, 19693}, {16890, 19770}, {16890, 19771}, {16976, 17706}, {16976, 17825}, {16976, 18968}, {16976, 19076}, {16976, 19175}, {16976, 19309}, {16976, 19332}, {16976, 19776}, {16979, 17706}, {16979, 17825}, {16979, 18968}, {16979, 19076}, {16979, 19175}, {16979, 19309}, {16979, 19332}, {16979, 19776}, {17946, 17359}, {17946, 17360}, {17946, 18773}, {17946, 18774}, {17946, 18866}, {17946, 18867}, {17946, 18962}, {17946, 18963}, {17946, 18968}, {17946, 19070}, {17946, 19071}, {17946, 19076}, {17946, 19675}, {17946, 19676}, {17959, 17706}, {17959, 17825}, {17959, 18968}, {17959, 19076}, {17959, 19175}, {17959, 19309}, {17959, 19332}, {17959, 19776}, {18021, 17376}, {18021, 17377}, {18021, 18773}, {18021, 18774}, {18021, 18866}, {18021, 18867}, {18021, 19326}, {18021, 19327}, {18021, 19332}, {18021, 19692}, {18021, 19693}, {18021, 19770}, {18021, 19771}, {18021, 19776}, {18061, 17706}, {18061, 17825}, {18061, 18968}, {18061, 19076}, {18061, 19175}, {18061, 19309}, {18061, 19332}, {18061, 19776}, {19163, 5023}, {19163, 5925}, {19163, 6150}, {19163, 6172}, {19163, 6608}, {19163, 6616}, {19163, 10548}, {19163, 11450}, {19163, 11675}, {19163, 11697}, {19163, 12133}, {19163, 12141}, {19163, 19332}, {19163, 19776}, {19166, 5023}, {19166, 5925}, {19166, 6150}, {19166, 6172}, {19166, 6608}, {19166, 6616}, {19166, 10548}, {19166, 11450}, {19166, 11675}, {19166, 11697}, {19166, 12133}, {19166, 12141}, {19166, 19332}, {19166, 19776}, {19169, 5017}, {19169, 5018}, {19169, 5919}, {19169, 5920}, {19169, 6150}, {19169, 6166}, {19169, 6167}, {19169, 6524}, {19169, 6525}, {19169, 6532}, {19169, 6533}, {19169, 6602}, {19169, 6603}, {19169, 6610}, {19169, 6611}, {19169, 10542}, {19169, 10543}, {19169, 11444}, {19169, 11445}, {19169, 11675}, {19169, 11691}, {19169, 11692}, {19169, 12049}, {19169, 12050}, {19169, 12057}, {19169, 12058}, {19169, 12127}, {19169, 12128}, {19169, 12135}, {19169, 12136}, {19169, 19326}, {19169, 19327}, {19169, 19692}, {19169, 19693}, {19169, 19770}, {19169, 19771}, {19230, 4963}, {19230, 4964}, {19230, 5613}, {19230, 5614}, {19230, 5706}, {19230, 5707}, {19230, 5919}, {19230, 5920}, {19230, 5925}, {19230, 6524}, {19230, 6525}, {19230, 6602}, {19230, 6603}, {19230, 6608}, {19230, 10488}, {19230, 10489}, {19230, 11138}, {19230, 11139}, {19230, 11231}, {19230, 11232}, {19230, 11444}, {19230, 11445}, {19230, 11450}, {19230, 12049}, {19230, 12050}, {19230, 12127}, {19230, 12128}, {19230, 12133}, {19230, 18773}, {19230, 18774}, {19230, 18866}, {19230, 18867}, {19433, 5006}, {19433, 5808}, {19433, 5916}, {19433, 5925}, {19433, 6014}, {19433, 6608}, {19433, 10531}, {19433, 11333}, {19433, 11441}, {19433, 11450}, {19433, 11539}, {19433, 12133}, {19433, 18968}, {19433, 19076}, {19436, 5006}, {19436, 5808}, {19436, 5916}, {19436, 5925}, {19436, 6014}, {19436, 6608}, {19436, 10531}, {19436, 11333}, {19436, 11441}, {19436, 11450}, {19436, 11539}, {19436, 12133}, {19436, 18968}, {19436, 19076}, {19439, 5000}, {19439, 5001}, {19439, 5802}, {19439, 5803}, {19439, 5910}, {19439, 5911}, {19439, 5919}, {19439, 5920}, {19439, 6014}, {19439, 6515}, {19439, 6516}, {19439, 6524}, {19439, 6525}, {19439, 6602}, {19439, 6603}, {19439, 10525}, {19439, 10526}, {19439, 11327}, {19439, 11328}, {19439, 11435}, {19439, 11436}, {19439, 11444}, {19439, 11445}, {19439, 11539}, {19439, 12040}, {19439, 12041}, {19439, 12049}, {19439, 12050}, {19439, 12127}, {19439, 12128}, {19439, 18962}, {19439, 18963}, {19439, 19070}, {19439, 19071}, {19439, 19675}, {19439, 19676}, {19652, 4963}, {19652, 4964}, {19652, 5613}, {19652, 5614}, {19652, 5706}, {19652, 5707}, {19652, 5919}, {19652, 5920}, {19652, 5925}, {19652, 6524}, {19652, 6525}, {19652, 6602}, {19652, 6603}, {19652, 6608}, {19652, 10488}, {19652, 10489}, {19652, 11138}, {19652, 11139}, {19652, 11231}, {19652, 11232}, {19652, 11444}, {19652, 11445}, {19652, 11450}, {19652, 12049}, {19652, 12050}, {19652, 12127}, {19652, 12128}, {19652, 12133}, {19652, 18773}, {19652, 18774}, {19652, 18866}, {19652, 18867}}, {0, 0, 10, 0, 20, 0, 10, 0, 0} -> {{11851, 5062}, {11851, 5063}, {11851, 5075}, {11851, 5076}, {11851, 5081}, {11851, 5794}, {11851, 5864}, {11851, 6483}, {11851, 10507}, {11851, 10508}, {11851, 10513}, {11851, 10587}, {11851, 10588}, {11851, 11319}, {11851, 11389}, {11851, 12008}, {11851, 17530}, {11851, 17531}, {11851, 17536}, {11864, 5081}, {11864, 5794}, {11864, 6146}, {11864, 10513}, {11864, 11319}, {11864, 11671}, {11864, 17536}, {11864, 17635}, {11864, 17769}, {11864, 18236}, {11926, 5062}, {11926, 5063}, {11926, 5075}, {11926, 5076}, {11926, 5081}, {11926, 5864}, {11926, 6146}, {11926, 6483}, {11926, 10507}, {11926, 10508}, {11926, 10513}, {11926, 10587}, {11926, 10588}, {11926, 11389}, {11926, 11671}, {11926, 12008}, {11926, 18230}, {11926, 18231}, {11926, 18236}, {11966, 5081}, {11966, 5794}, {11966, 6146}, {11966, 10513}, {11966, 11319}, {11966, 11671}, {11966, 17536}, {11966, 17635}, {11966, 17769}, {11966, 18236}, {15128, 17536}, {15128, 17635}, {15128, 17769}, {15128, 18236}, {15128, 18954}, {15128, 19306}, {15131, 17536}, {15131, 17635}, {15131, 17769}, {15131, 18236}, {15131, 18954}, {15131, 19306}, {15134, 17530}, {15134, 17531}, {15134, 17635}, {15134, 17769}, {15134, 18230}, {15134, 18231}, {15134, 18954}, {15134, 19024}, {15134, 19306}, {15134, 19643}, {15205, 17536}, {15205, 17635}, {15205, 17769}, {15205, 18236}, {15205, 18954}, {15205, 19306}, {15208, 17536}, {15208, 17635}, {15208, 17769}, {15208, 18236}, {15208, 18954}, {15208, 19306}, {16175, 17530}, {16175, 17531}, {16175, 17536}, {16175, 18954}, {16175, 19024}, {16175, 19643}, {16188, 17536}, {16188, 17635}, {16188, 17769}, {16188, 18236}, {16188, 18954}, {16188, 19306}, {16250, 18230}, {16250, 18231}, {16250, 18236}, {16250, 19024}, {16250, 19306}, {16250, 19643}, {16290, 17536}, {16290, 17635}, {16290, 17769}, {16290, 18236}, {16290, 18954}, {16290, 19306}, {16884, 17536}, {16884, 17635}, {16884, 17769}, {16884, 18236}, {16884, 18954}, {16884, 19306}, {16887, 17536}, {16887, 17635}, {16887, 17769}, {16887, 18236}, {16887, 18954}, {16887, 19306}, {16890, 17530}, {16890, 17531}, {16890, 17635}, {16890, 17769}, {16890, 18230}, {16890, 18231}, {16890, 18954}, {16890, 19024}, {16890, 19306}, {16890, 19643}, {16976, 17536}, {16976, 17635}, {16976, 17769}, {16976, 18236}, {16976, 18954}, {16976, 19306}, {16979, 17536}, {16979, 17635}, {16979, 17769}, {16979, 18236}, {16979, 18954}, {16979, 19306}, {17946, 17530}, {17946, 17531}, {17946, 17536}, {17946, 18954}, {17946, 19024}, {17946, 19643}, {17959, 17536}, {17959, 17635}, {17959, 17769}, {17959, 18236}, {17959, 18954}, {17959, 19306}, {18021, 18230}, {18021, 18231}, {18021, 18236}, {18021, 19024}, {18021, 19306}, {18021, 19643}, {18061, 17536}, {18061, 17635}, {18061, 17769}, {18061, 18236}, {18061, 18954}, {18061, 19306}, {19163, 5081}, {19163, 6146}, {19163, 10513}, {19163, 11671}, {19163, 18236}, {19163, 19306}, {19166, 5081}, {19166, 6146}, {19166, 10513}, {19166, 11671}, {19166, 18236}, {19166, 19306}, {19169, 5062}, {19169, 5063}, {19169, 5075}, {19169, 5076}, {19169, 5864}, {19169, 6146}, {19169, 6483}, {19169, 10507}, {19169, 10508}, {19169, 10587}, {19169, 10588}, {19169, 11389}, {19169, 11671}, {19169, 12008}, {19169, 18230}, {19169, 18231}, {19169, 19024}, {19169, 19306}, {19169, 19643}, {19230, 5062}, {19230, 5063}, {19230, 5075}, {19230, 5076}, {19230, 5081}, {19230, 5864}, {19230, 6483}, {19230, 10507}, {19230, 10508}, {19230, 10513}, {19230, 10587}, {19230, 10588}, {19230, 11389}, {19230, 12008}, {19230, 19024}, {19230, 19643}, {19433, 5081}, {19433, 5794}, {19433, 10513}, {19433, 11319}, {19433, 17536}, {19433, 18954}, {19436, 5081}, {19436, 5794}, {19436, 10513}, {19436, 11319}, {19436, 17536}, {19436, 18954}, {19439, 5062}, {19439, 5063}, {19439, 5075}, {19439, 5076}, {19439, 5794}, {19439, 5864}, {19439, 6483}, {19439, 10507}, {19439, 10508}, {19439, 10587}, {19439, 10588}, {19439, 11319}, {19439, 11389}, {19439, 12008}, {19439, 17530}, {19439, 17531}, {19439, 18954}, {19439, 19024}, {19439, 19643}, {19652, 5062}, {19652, 5063}, {19652, 5075}, {19652, 5076}, {19652, 5081}, {19652, 5864}, {19652, 6483}, {19652, 10507}, {19652, 10508}, {19652, 10513}, {19652, 10587}, {19652, 10588}, {19652, 11389}, {19652, 12008}, {19652, 19024}, {19652, 19643}}, {0, 0, 0, 0, 30, 0, 10, 0, 0} -> {{11851, 5739}, {11851, 5740}, {11851, 11264}, {11851, 11265}, {11864, 6086}, {11864, 6205}, {11864, 11611}, {11864, 11730}, {11926, 5756}, {11926, 5757}, {11926, 11281}, {11926, 11282}, {11966, 6086}, {11966, 6205}, {11966, 11611}, {11966, 11730}, {15128, 19246}, {15128, 19365}, {15131, 19246}, {15131, 19365}, {15134, 19240}, {15134, 19241}, {15134, 19359}, {15134, 19360}, {15205, 19246}, {15205, 19365}, {15208, 19246}, {15208, 19365}, {16175, 18899}, {16175, 18900}, {16188, 19246}, {16188, 19365}, {16250, 18916}, {16250, 18917}, {16290, 19246}, {16290, 19365}, {16884, 19246}, {16884, 19365}, {16887, 19246}, {16887, 19365}, {16890, 19240}, {16890, 19241}, {16890, 19359}, {16890, 19360}, {16976, 19246}, {16976, 19365}, {16979, 19246}, {16979, 19365}, {17946, 18899}, {17946, 18900}, {17959, 19246}, {17959, 19365}, {18021, 18916}, {18021, 18917}, {18061, 19246}, {18061, 19365}, {19163, 6214}, {19163, 11739}, {19166, 6214}, {19166, 11739}, {19169, 6208}, {19169, 6209}, {19169, 11733}, {19169, 11734}, {19230, 5748}, {19230, 5749}, {19230, 11273}, {19230, 11274}, {19433, 6078}, {19433, 11603}, {19436, 6078}, {19436, 11603}, {19439, 6072}, {19439, 6073}, {19439, 11597}, {19439, 11598}, {19652, 5748}, {19652, 5749}, {19652, 11273}, {19652, 11274}}|>

 *)

