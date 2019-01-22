% AXXB - Batch Method Noise
% 
% clear; clc; close all;
% 
% 
% Editable Variables
% ------------------------------------------------------

%%% TODO

clear; clc;

num = 210;	%Number of steps

gmean = [0;0;0;0;0;0];	%Gaussian Noise Mean

noise = (0:0.02:0.1);	%Gaussian Noise standard deviation Range

shift =0; %step shift
 
model = 1;        %noise model

ElipseParam = [10, 10, 10];

trials = 1;

% ------------------------------------------------------
addpath ./stochastics/utils/
addpath ./data_gen/
x = randn(6,1); X = expm(se3_vec(x));   %Generate a Random X


% Computation Loops
% ---------------------------------------------------------------------------------------------------------

RoterrorL2=[];
TranerrorL2=[];
RoterrorED=[];
TranerrorED=[];
RoterrorKron=[];
TranerrorKron=[];

h = waitbar(0,'Computing...');

for i=1:length(noise)
    
    for k = 1:trials
        
        A = [];
        MA   = [];
        SigA = [];
        B = [];
        MB   = [];
        SigB = [];
        C = [];
        SigX = [];
        
        trajParam = [.5, .5, .5, 0, 0];
        [A1, B1] = AB_genTraj(X, ElipseParam, trajParam, num/3);
        
        trajParam = [.5, .5, .5, 0, 0.5*pi];
        [A2, B2] = AB_genTraj(X, ElipseParam, trajParam, num/3);
        
        trajParam = [.5, .5, .5, 0, pi];
        [A3, B3] = AB_genTraj(X, ElipseParam, trajParam, num/3);
        
        A = cat(3, A1, A2, A3);
        B = cat(3, B1, B2, B3);
        
        A = sensorNoise(A,[0;0;0;0;0;0],noise(i),1);
        
        [a1,a2,a3]  = size(A);
%         A_noise_mex = reshape(A, a1, a2*a3);
%         B_mex = reshape(B, a1, a2*a3);

        [X_solved, MA, MB, SigA, SigB] = batchSolveNew(A, B, 2);
        X_solved
        X
        X_roterror(k,i) = roterror(X_solved,X);
        X_tranerror(k,i) = tranerror(X_solved,X);
        
    end
    
    waitbar(i / length(noise))
    
end

 X_meanroterror  = mean(X_roterror,1);
 X_meantranerror = mean(X_tranerror,1);


close(h);

figure(1);
plot(X_meanroterror)
figure(2);
plot(X_meantranerror)




% ---------------------------------------------------------------------------------------------------------


