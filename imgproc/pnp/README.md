In this folder, I tried to learn the famous Perspective N Point algorithm which aims to estimate transformation information from a batch (>=3) 3D-2D correspondence points.
For some algorithms, I re-implemented them, while for others, I just write a warpper to call them.

## Already Imeplemented:
1. P3P Gao;
2. P3P Kneip;
3. P3P Pst;
4. PnP AK;
5. PnP QuanLong;
6. LHM;
7. EPnP (intermediate result differs with the EPnP, but final result approaches with numerical error);
8. POSIT;

## use only Warpper to call 3rdparty implementation:
1. MLPnP: MLPnP may not be a good choice in my opinion: 1) extensive null vector computation for each 2D points; 2) ordinary case needs at least 6 points; 3) omit the constraint imposed by R; 4) use all 3D points for GN optimization.

## Useful links:
PnP toolbox: 
1. https://github.com/haoyinzhou/PnP_Toolbox
2. https://github.com/urbste/MLPnP_matlab_toolbox

## Not yet read:
1. AsPnP;
2. CEPPnP;
4. REPnP;
5. R1PnP;https://github.com/haoyinzhou/PnP_Toolbox
