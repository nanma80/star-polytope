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
	"polytope_3_4_3",
	(* "polytope_5_3_3_cell120" *)
	"polytope_3_3_5_cell600",
	"bitruncated_3_4_3"
};
(*shape = "test";*)

exportToPov = False;
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
getCellCenter[cell_] := Simplify[Total[Flatten[cell, 1]]];
explodedFace[face_, explosionFactor_] := Map[(# + Mean[face] * explosionFactor)&, face];
explodedCell[cell_, explosionFactor_] := Map[
	(# + Mean[Map[Mean,cell]]*(Norm[First[First[cell]]//N]/Norm[Mean[Map[Mean,cell]]//N])^1.5 * explosionFactor)&, 
	cell, {2}];
normalizedAngle[u_, v_] := ArcSin[u.v/Norm[u]/Norm[v]]/Pi + 0.5;
projectToDirection[vertex4d_, projectionMatrix_] := vertex4d.Transpose[projectionMatrix];
(* perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]] / (1 + point.(fullProjectionMatrix[[4]])/wDistance); *)
perspectiveProjection[point_, fullProjectionMatrix_, wDistance_ ] := projectToDirection[point, fullProjectionMatrix[[1;;3]]];
normalizedInner[u_, v_] := u.v/Norm[u]/Norm[v];
doubleRotationMatrix[theta_] := ArrayFlatten[{{RotationMatrix[-theta], 0}, {0, RotationMatrix[-theta]}}];
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


exportImage[shape_, activeLayerMin_, activeLayerMax_, explosionFactor_, theta_, serialNumber_] := Module[
	{
		dataFileName,
		shapeTokens,
		color,
		cellShape,
		cells,
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

	(* If[serialNumber != 1 && serialNumber != 20, Return[]]; *)
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

	cellsByLayers = GroupBy[cells, getCellCenter[#][[4]]&];
	layerKeys = Sort[Keys[cellsByLayers], Greater];
	Print["There are " <> IntegerString[Length[layerKeys]] <> " layers in total. Layer keys:"];
	Print[N[layerKeys]];

	thickness = Norm[cells[[1]][[1]][[1]]] * 0.008;
	lighting = {{"Point", White, viewPoint * 10}};
	range = Norm[cells[[1]][[1]][[1]]] * rangeFactor;

	outputFolder = shape <> "_double_rotation";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];

	outputFileName = "animation_" <> shape <> "_layers_" <> IntegerString[activeLayerMin] <> "_" <> IntegerString[activeLayerMax] <> "_" <> IntegerString[serialNumber, 10, 4] <> ".png";
	If[exportToPov, outputFileName = "pov_" <> outputFileName ];
	outputFileName = FileNameJoin[{outputFolder, outputFileName}];

	imageSize = imageSizes[If[activeLayerMin < activeLayerMax, "allLayers", "singleLayer"]];
	cropCommand = "mogrify -crop " <> IntegerString[imageSize[[2]]] <> "x" <> IntegerString[imageSize[[2]]] <> "+" <> IntegerString[(imageSize[[1]]-imageSize[[2]])/2] <> "+0 " <> outputFileName;

	inactiveCells = Apply[Join, Table[cellsByLayers[layerKeys[[k]]], {k, 1, activeLayerMin - 1}]];
	Print["Selected " <> IntegerString[Length[inactiveCells]] <> " inactive cells."];

	inactiveFaces = Union[ Flatten[inactiveCells, 1], SameTest -> sameCenter];
	inactiveEdges = Union[ Flatten[Map[getEdgesFromFace, inactiveFaces], 1], SameTest -> sameCenter];
	inactiveVertices = Union[ Flatten[inactiveFaces,1], SameTest -> sameVertex];

	activeCells = Apply[Join, Table[cellsByLayers[layerKeys[[k]]], {k, activeLayerMin, activeLayerMax}]];
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
    Print[wDistance];

    rotation3D = IdentityMatrix[3];
    (* for 600 cell, the following will lead to 60 rings. Each ring has 10 cells *)
    If[shape == "polytope_5_3_3_cell120" || shape == "polytope_3_3_5_cell600", rotation3D = RotationMatrix[-ArcTan[1/phi], {0, 1, 0}]];
    If[shape == "polytope_3_4_3" || shape == "bitruncated_3_4_3", rotation3D = RotationMatrix[Pi/6, {0, 0, 1}].RotationMatrix[-ArcTan[Sqrt[2]], {1, 0, 0}].RotationMatrix[Pi/4, {0, 0, 1}]];

    fullProjectionMatrix = ArrayFlatten[
    	{{rotation3D, 0}, {0, 1}}
	];

	(* If[shape == "polytope_3_3_5_cell600", fullProjectionMatrix = ArrayFlatten[{{1, 0, 0}, {0, RotationMatrix[-ArcTan[Sqrt[2]]], 0}, {0, 0, 1}}].ArrayFlatten[{{IdentityMatrix[2], 0}, {0, RotationMatrix[Pi/4]}}] ]; *)

	fullProjectionMatrix = doubleRotationMatrix[theta].fullProjectionMatrix;

(* 	perspectiveProjection[activeCellsCenters[[11]], fullProjectionMatrix, wDistance]
	centers = Table[ perspectiveProjection[activeCellsCenters[[k]], fullProjectionMatrix, wDistance], {k, 120}]
	Select[centers, Norm[{#[[1]], #[[2]]}] < 0.01&]
 *)
    projectedActiveFaces = Map[perspectiveProjection[#, fullProjectionMatrix, wDistance]&, activeFaces, {2}];
    range = Max[Flatten[activeFaces]] * 2.3;
    range = Max[Flatten[activeFaces]] * 1.4; (* 120-cell *)
    If[shape == "polytope_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 2.2;
    	viewPoint = {1.0, -0.9, 0.5}];
    If[shape == "polytope_3_3_5_cell600", 
    	range = Max[Flatten[activeFaces]] * 1.5;
    	viewPoint = {1.2, -0.7, 0.5}];
	If[shape == "bitruncated_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 1.1;
    	viewPoint = {1.2, -0.7, 0.5}];
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

    rotatedActiveFaces = Map[projectToDirection[#, fullProjectionMatrix]&, activeFaces, {2}];

(*     Print[projectedActiveFaces[[1]][[1]]];
    Print[rotatedActiveFaces[[1]][[1]]];
    Exit[]; *)

    For[k = 1, k <= Length[activeFaces], k++,
    	cellId = Floor[(k - 1)/faceCellRatio] + 1;
    	(* If[cellId < 27 || cellId > 27, Continue[]]; *)
    	faceIdInCell = Mod[(k - 1), faceCellRatio] + 1;
    	(* Print[faceIdInCell]; *)
    	normInner = normalizedInner[rotatedActiveCellsCenters[[cellId]], ( {0, 0, 0, wDistance})];
    	opacityStart = -0.0;
		opacityEnd = 0.1;
		(* linear opacity transition *)
		(* opacity = If[normInner > opacityEnd, 1, If[normInner < opacityStart, 0, (normInner - opacityStart)/(opacityEnd - opacityStart)]]; *)

		(* quadratic transition *)
		opacity = If[normInner > opacityEnd, 1, 
					  If[normInner < opacityStart, 0, 
					   1 - ((normInner - opacityEnd)/(opacityEnd - opacityStart))^2]];

		faceTemp = projectedActiveFaces[[k]];
		faceNormalVector = Cross[faceTemp[[2]] - faceTemp[[1]], faceTemp[[3]] - faceTemp[[2]]];
		faceCenter = Mean[faceTemp];
		cellCenter4d = rotatedActiveCellsCenters[[cellId]];
		
		faceCenter4d = Mean[rotatedActiveFaces[[k]]];
		projectedFaceCenter = (faceCenter4d - cellCenter4d)[[{1,2,3}]];

		faceVisible = (Dot[faceNormalVector, viewPoint] * Dot[faceNormalVector, projectedFaceCenter] > - roundPrecision);
		(* faceVisible = True; *)

    	If[opacity > roundPrecision && faceVisible,
    		AppendTo[graphFaces,
    			{
    				Opacity[opacity],
    				If[opacity > 0.85, EdgeForm[Thin], EdgeForm[]],
					Polygon[ projectedActiveFaces[[k]] ]
				}
    		];
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
		Boxed -> False,
		ViewAngle -> range/Norm[viewPoint]/100/6.7
	];

	If[exportToPov,
		If[FileExistsQ[outputFileName], DeleteFile[outputFileName]];
		POVRayRender[graph, Method -> "Triangle", OutputPath -> outputFileName, ImageSize -> imageSize, RenderOptions -> "+A0.001 -J +UA"];
		Run[cropCommand];
		,
		Export[outputFileName, graph, ImageSize -> imageSize[[2]]];
	]
	Print["Saved the image to " <> outputFileName];
]

exportAnimation[shape_, activeLayerMin_, activeLayerMax_] := Module[
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

	outputFolder = shape <> "_double_rotation";
	outputFolder = FileNameJoin[{imageFolder, outputFolder}];
	If[!DirectoryQ[outputFolder], CreateDirectory[outputFolder]];
	gifFileName = shape <> "_double_rotation_towle";
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
		exportImage[shape, activeLayerMin, activeLayerMax, explosionFactor, theta, frameIndex];
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
]

For[shapeIndex = 1, shapeIndex <= Length[shapes], shapeIndex ++,
	shape = shapes[[shapeIndex]];	
	If[
		StringContainsQ[shape, "polytope_3_3_"],
		activeLayerMin = 1; activeLayerMax = 15,
		activeLayerMin = 1; activeLayerMax = 9
	];
	If[shape == "polytope_3_4_3", activeLayerMax = 5];
	If[shape == "bitruncated_3_4_3", activeLayerMax = 7];
    
	exportAnimation[shape, activeLayerMin, activeLayerMax];
];

(* exportImage[shape, 1, activeLayerMax, 2.9, Pi/4 * 10/100., 1]; *)
(* deltaTheta = Pi/240; *)
(* exportImage[shape, 1, 9, 2.9, 48 deltaTheta, 9]; *)
(* exportImage[shape, 1, 9, 2.9, 0 deltaTheta, 10]; *)
(* exportImage[shape, 1, 9, 2.9, 1 deltaTheta, 11]; *)
(* exportImage[shape, 1, 9, 2.9, 2 deltaTheta, 12]; *)
(* exportImage[shape, 1, 9, 2.9, 3 deltaTheta, 13]; *)
(* exportImage[shape, 1, 9, 2.9, 4 deltaTheta, 14]; *)

