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
		(* Print[rotationSchedule]; *)
		(* Print[FromCharacterCode[{7, 7, 7}]]; *)
		

		activeFaces = Union[ Flatten[rotatedCells[[highlightedCellIds]], 1], SameTest -> sameCenter ];
		If[Length[activeFaces] == 720 || forceQuit,
			activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter];
			If[Length[activeEdges] == 720 || forceQuit,
				activeVertices = Union[ Flatten[activeFaces,1], SameTest -> ApproxSamePoint];
				If[Length[activeVertices] == 120 || forceQuit,
					Print["Found a good net"];
					Print["Element counts: cells, faces, edges, vertices:"];
					Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]];
					Print[rotationSchedule];
					(* Print[FromCharacterCode[{7, 7, 7}]]; *)
					(* Exit[]; *)
				];
			];
		];
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
otherLayers = {3, 7, 5};
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

fileNameLayer1 = "candidateStep3_layer_37";
fileNameLayer2 = "candidateStep2_layer_5";

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
		

	];
	If[resultCount > 10, Break[]];
];

fileName = "candidateStep4_layer_357";

exportDataFileName = FileNameJoin[{dataFolder, "folding_120_cell", fileName <> ".wl"}];

If[FileExistsQ[exportDataFileName], DeleteFile[exportDataFileName]];
Save[exportDataFileName, exportData];












Exit[];

