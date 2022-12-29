#!/usr/bin/env wolframscript

(*
mogrify -crop 450x450+75+0 -path . pov_*.png
mogrify -crop 300x300+50+0 -path . explode*.gif

magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay 5 -dispose 2 *.png out.gif
magick convert out.gif -coalesce -duplicate 1,-2-1 -quiet -layers OptimizePlus  -loop 0 cycle.gif
python -m SimpleHTTPServer 8000

*)

(* global config *)

(* frameCount = 10; *)
frameCount = 200;

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
	(* "polytope_5_3_3_cell120" *)
	"polytope_3_3_5_cell600"
	(* "polytope_3_3_4" *)
	(* "polytope_3_3_52" *)
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

colors = {Brown, Yellow, Blue, Green, Cyan, Red, Purple, Orange, GrayLevel[0.5] }//Reverse;
colors = Join[colors, RandomColor[22]];
Print["colors"];
Print[colors];

(* one realization, for consistency *)
colors = {GrayLevel[0.5], RGBColor[1, 0.5, 0], RGBColor[0.5, 0, 0.5], RGBColor[1, 0, 0], RGBColor[0, 1, 1], RGBColor[0, 1, 0], RGBColor[0, 0, 1], RGBColor[1, 1, 0], RGBColor[0.6, 0.4, 0.2], RGBColor[0.8105083771645483, 0.23663910012583567, 0.9729724714759138], RGBColor[0.4557800892072139, 0.8234255243528599, 0.9418538225276114], RGBColor[0.5069713088717647, 0.1380399589796435, 0.19818135119997504], RGBColor[0.2806740950494051, 0.3345641912556099, 0.7331840382027028], RGBColor[0.6990518103172214, 0.6930044550663568, 0.21216510098565355], RGBColor[0.635757416229463, 0.2805162691577381, 0.06597817940854078], RGBColor[0.07304761358679368, 0.31593429655179883, 0.8113773066626391], RGBColor[0.9495640041418516, 0.7659294996073056, 0.6003537437365118], RGBColor[0.8328776949418131, 0.3685282033460118, 0.7052695612598112], RGBColor[0.35081137933012174, 0.881099836794254, 0.47760936834021805], RGBColor[0.7777753167949859, 0.8251038447392216, 0.16601549689517126], RGBColor[0.4449309065416689, 0.6322731203349534, 0.6291439048555509], RGBColor[0.24322046711504153, 0.0891596610827492, 0.46520471005013464], RGBColor[0.43432540122159424, 0.024885395526281107, 0.2181294067744901], RGBColor[0.021260327105693477, 0.5419837395492464, 0.052403481011500386], RGBColor[0.3622508277723713, 0.4103831876922248, 0.29828023549958105], RGBColor[0.07200671983615048, 0.8046114145871346, 0.9387164377216226], RGBColor[0.4433616581728024, 0.6446156492388302, 0.419397360522628], RGBColor[0.35117845515707447, 0.8432311313509513, 0.8943553143329561], RGBColor[0.6594666395066768, 0.31036553489567353, 0.7321958736332197], RGBColor[0.00523150782617221, 0.17778574255011081, 0.8113615450824387], RGBColor[0.12288040075655227, 0.2059601403945157, 0.7977872301981275]};

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

    range = If[negativeFold, 1.8, 6];
    viewPoint = {50, -50, 50};

    If[shape == "polytope_3_4_3", 
    	range = Max[Flatten[activeFaces]] * 2.2;
    	viewPoint = {1.0, -0.9, 0.5}];
    If[shape == "polytope_3_3_5_cell600", 
    	range = Max[Flatten[activeFaces]] * 0.8;
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
	    color = cellColors[[cellId]];
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

smoothFall[x_, start_, duration_] := If[x < start, 1, If[x > start + duration, 0, (1 + Cos[(x - start)/duration*Pi])/2]];

exportAnimation[shape_] := Module[
	{
		outputFolder,
		gifFileName,
		gifFolder,
		explosionConfig,
		maxExplosionFactor,
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
	explodeStep = maxExplosionFactor/frameCount;

	explosionFactor = 2.9 * If[shape == "polytope_3_3_5_cell600", 5, 1];
	explosionFactor = 0.4; (* 120-cell *)
	If[shape == "polytope_3_3_5_cell600", explosionFactor = 0.7];
	If[shape == "polytope_3_4_3", explosionFactor = 0.4];

(* 	angleSpan = Pi/5;
    If[shape == "polytope_3_4_3", 
    	frameCount = 200;
    	angleSpan = 2 Pi/6];
    If[shape == "bitruncated_3_4_3", 
    	frameCount = 200;
    	angleSpan = 2 Pi/6];
 *)    (* frameCount = 20; *)

	negativeFold = True;
	(* negativeFold = False; *)

	(* unfoldPercents = Table[k/(frameCount-1), {k, 0, frameCount-1}]; *)
	unfoldPercents = Table[smoothFall[x, 0, 1]//N, {x, 0, 1, 1/(frameCount-1)}, {k, maxLevel}];
	zeros = Table[0.0, {x, 0, 1, 1/(frameCount/2 - 1)}, {k, maxLevel}];
	minusOnes = Table[-1.0, {x, 0, 1, 1/(frameCount/4 - 1)}, {k, maxLevel}];
	unfoldPercents = Join[unfoldPercents, zeros, zeros, unfoldPercents - 1, minusOnes];

	explosionFactors = Join[
			Table[0.0, {x, 0, 1, 1/(frameCount-1)}], 
			Table[(1-smoothFall[x, 0, 1]) * 1.5, {x, 0, 1, 1/( frameCount/2 - 1 )}]
		];
	explosionFactors = Join[explosionFactors, Reverse[explosionFactors], Table[0.0, {x, 0, 1, 1/(frameCount/4-1)}] ];

	Print[unfoldPercents];
	Print[explosionFactors];

	For[frameIndex = 1, frameIndex <= Length[unfoldPercents], frameIndex++,
		Continue[];
		(* If[frameIndex < 400, Continue[]]; *)
		unfoldPercent = unfoldPercents[[frameIndex]];
		Print["exporting frame " <> IntegerString[frameIndex] <> " / " <> IntegerString[Length[unfoldPercents]] ];
		(* exportFrame[faces, rotationSchedule, 1, spinAngle, frameIndex, outputFolderName]; *)
		(* spinAngle = -Pi/2 - If[p == 4, Pi/6, Pi/4] - frameIndex/Length[unfoldPercents] * 2 * Pi; *)
		rotatedCells = foldCells[cells, rotationSchedule, unfoldPercent];
		explosionFactor = explosionFactors[[frameIndex]];
		exportImage[shape, rotatedCells, explosionFactor, 0, frameIndex];
	];

    delay = If[frameCount > 30, 3, 50];

    gifCommand = "magick convert -duplicate 1,-2-1 -quiet +repage -alpha remove -loop 0 -delay "  (* loop back*)
    (* gifCommand = "magick convert -quiet +repage -alpha remove -loop 0 -delay " (* no looping back *) *)
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

findDihedralAngle[cells_] := Module[
	{cell1Id, cell2Id},

	cell1Id = 1;
	cell2Ids = Select[Range[Length[cells]], adjacentCellsIndex[cells, cell1Id, #]&];
	Print[cell2Ids];
	cell2Id = cell2Ids[[1]];

	cell1 = cells[[cell1Id]];
	cell2 = cells[[cell2Id]];
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

	originalDihedralAngle = ArcCos[ Dot[relativeCell1, relativeCell2]/Norm[relativeCell1]/Norm[relativeCell2] ];
	Print[originalDihedralAngle//FullSimplify];
	Print[originalDihedralAngle/Pi * 180.0];
	Exit[];
	originalDihedralAngle
];

(* findDihedralAngle[cells]; *)

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

	adjMatrixFileName = "adjMatrix_600_cell";

	adjMatrixFileName = FileNameJoin[{dataFolder, "folding_600_cell", adjMatrixFileName <> ".wl"}];

	If[FileExistsQ[adjMatrixFileName],
		adjMatrix = Get[adjMatrixFileName],
		adjMatrix = {};
		For[id1 = 1, id1 <= limit, id1++,
			row = Table[If[adjacentCellsIndex[cells, id1, id2], 1, 0], {id2, 1, limit}];
			Print[id1];
			AppendTo[adjMatrix, row];
		];

		Save[adjMatrixFileName, adjMatrix];
	];

	(* Print[adjMatrix]; *)

	graph = AdjacencyGraph[Range[Length[adjMatrix]], adjMatrix ];
	spanningTree = FindSpanningTree[DirectedGraph[graph]];
	tree = GraphTree[spanningTree];

	rootCellId = TreeData[tree];

	rotationSchedule = {};

	rotationSchedule = buildSchedule[tree, rotationSchedule, 1];
	rotationSchedule
];

rootCellId = 1;

rotationSchedule = getRotationSchedule[cells];

rotation3D = IdentityMatrix[3];
(* for 600 cell, the following will lead to 60 rings. Each ring has 10 cells *)
(* If[shape == "polytope_5_3_3_cell120" || shape == "polytope_3_3_5_cell600", rotation3D = RotationMatrix[-ArcTan[1/phi], {0, 1, 0}]];
If[shape == "polytope_3_4_3" || shape == "bitruncated_3_4_3", rotation3D = RotationMatrix[Pi/6, {0, 0, 1}].RotationMatrix[-ArcTan[Sqrt[2]], {1, 0, 0}].RotationMatrix[Pi/4, {0, 0, 1}]];

fullProjectionMatrix = ArrayFlatten[
	{{rotation3D, 0}, {0, 1}}
];
 *)
rootCellCenter = getCellCenter[cells[[rootCellId]]]//N;
(* Print[rootCellCenter]; *)
fullProjectionMatrix = RotationMatrix[{ getCellCenter[cells[[rootCellId]]], {0, 0, 0, -1} }];

cells = Map[#.Transpose[fullProjectionMatrix] &, cells, {2}];
Print["getting cell centers"];
cellCenters = Map[getCellCenter, cells//N];

Print["grouping cells by layer"];
layerGroupBy = 
 GroupBy[Range[Length[cellCenters]], 
  Round[cellCenters[[#]][[4]], epsilon] &];
originalDepths = Sort[Keys[layerGroupBy]];
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

(* cellColors = Map[getHue[mapHopfFibration[#]]&, cellCenters]; *)
cellColors = Map[colors[[ layerMap[#] ]]&, Range[Length[cells]]];
(* cellColors = Map[Red&, Range[Length[cells]]]; *)

(* rootCellCenter = getCellCenter[cells[[rootCellId]]]; *)
(* Print[rootCellCenter//N]; *)
(* Exit[]; *)

maxLevel = Max[Map[#[[3]]&, rotationSchedule ]];
Print["maxLevel: "];
Print[maxLevel];

foldCells[cells_, rotationSchedule_, foldPercents_] := Module[
	{originalDihedralAngle, rotatedCells, scheduleId, level, schedule, cell1Id, cell2Id, rotatedCellIds},
	originalDihedralAngle = 0;
	rotatedCells = N[cells];

	For[scheduleId = 1, scheduleId <= Length[rotationSchedule], scheduleId++,
		schedule = rotationSchedule[[scheduleId]];
		level = schedule[[3]];
		If[level >= 1,
			(* Print[schedule]; *)
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
			
			originalDihedralAngle = ArcCos[ Dot[relativeCell1, relativeCell2]/Norm[relativeCell1]/Norm[relativeCell2] ]//N;
			
(* 			Print["originalDihedralAngle"];
			Print[originalDihedralAngle / Pi * 180.]; *)
			(* 
				600-cell: ArcCos[-1/8 - (3*Sqrt[5])/8], 164.47751218593
				grand 600-cell: ArcCos[-1/8 + (3*Sqrt[5])/8], 44.47751218592993
				5-cell {3,3,3}: ArcSec[4], 75.52248781407008
				16-cell {3,3,4}: (2*Pi)/3, 120.0
			*)
			
			grand600CellDihedralAngle = ArcCos[-1/8 + (3*Sqrt[5])/8]//N;
			cell5DihedralAngle = ArcSec[4]//N;
			cell16DihedralAngle = (2*Pi)/3//N;

			angleToFlat = Pi - originalDihedralAngle;
			angleToStellate = grand600CellDihedralAngle - originalDihedralAngle;
			(* angleToStellate = cell5DihedralAngle - originalDihedralAngle; *)
			(* angleToStellate = cell16DihedralAngle - originalDihedralAngle; *)

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

	Print["Dihedral angle:"];
	Print[(angleToTarget * Abs[perc] + originalDihedralAngle)/Pi * 180.0];

	rotatedCenters = Map[getCellCenter, rotatedCells];
	uniqueCenters = Union[rotatedCenters, SameTest -> ApproxSamePoint];
(* 	Print["unique center count:"];
	Print[Length[uniqueCenters]]; *)
	(* Exit[]; *)

	If[False,
		activeFaces = Union[ Flatten[rotatedCells, 1], SameTest -> sameCenter ];
		activeEdges = Union[ Flatten[Map[getEdgesFromFace, activeFaces], 1], SameTest -> sameCenter];
		activeVertices = Union[ Flatten[activeFaces,1], SameTest -> ApproxSamePoint];
		Print["Element counts: cells, faces, edges, vertices:"];
		Print[Map[Length, {uniqueCenters, activeFaces, activeEdges, activeVertices}]];

		(* 
		600-cell:
		{600, 1200, 720, 120}

		grand 600-cell:
		{600, 1200, 720, 120}

		5-cell:
		{5, 10, 10, 5}

		16-cell:
		{16, 32, 24, 8}
 *)
	];

	rotatedCells
];

exportAnimation[shape];


(* 
for ($num = 627 ; $num -le 650 ; $num++) { cp pov_animation_polytope_3_3_5_cell600_0626.png "pov_animation_polytope_3_3_5_cell600_0$num.png" }
 *)

(* exportImage[shape, 1, 9, 2.9, 1 deltaTheta, 11]; *)
(* exportImage[shape, 1, 9, 2.9, 2 deltaTheta, 12]; *)
(* exportImage[shape, 1, 9, 2.9, 3 deltaTheta, 13]; *)
(* exportImage[shape, 1, 9, 2.9, 4 deltaTheta, 14]; *)

(* 	dataFileName = FileNameJoin[{dataFolder, shape <> ".wl"}];
	Print["Reading data for " <> shape <> " from " <> dataFileName];

	cells = Get[dataFileName];
	Print["There are " <> IntegerString[Length[cells]] <> " cells in total."];
 *)