    clc;
    close all;
    clear all;

    %% simulation of homography decomposition
    addpath('../../../MatrixLieGroup');
    addpath('../../../quaternion');
    addpath('../../../beautiful_plot');
    addpath('../');
    addpath ../3rdparty/OPnP_Toolbox_Original/OPnP/
    
    T1 = fakeRT();
    
    N = 20;
    p = rand([3,N]) * 5 - 2.5;
%     p(3,:) = 5;% + rand(1);
    p(1,:) = p(1,:);
    p(2,:) = p(2,:);
    
    K = [100 0 0;0 100 0;0 0 1];
    
    [uv1, in1] = proj(T1, p, K);
    im = zeros(240,320);
    
    q1 = uv1(:,in1);
    P = p(:,in1);
    
    pr = T1(1:3,1:3)*p + repmat(T1(1:3,4),1,N);
    pr = pr(:,in1);
    
    id = randperm(size(q1,2),3);
    pr(:,id)
    T1
%     pr(:,:)
    
    q1n = K\q1;
%     
%     P = [
%     1.8621    2.1255    2.4196    1.6199    2.3535; ...
%     0.5063    0.0265    2.3989    1.7610    1.7062; ...
%     5.0000    5.0000    5.0000    5.0000    5.0000];
%     q1 = [
%             0.2305    0.3077    0.1587    0.0938    0.2051; ...
%     0.2742    0.2255    0.5951    0.4374    0.4888; ...
%     1.0000    1.0000    1.0000    1.0000    1.0000];
%     K = eye(3);
%     q1n = K\q1;
%     [R,t] = pnp_long(P(:,1:4), q1(:,1:4), K);
%     [R, t] = OPnP(P, q1n, K);
%     [R,t] = pnp_gOp(P, q1, K);
%     [R,t] = pnp_sdr(P, q1, K, T1(1:3,1:3), T1(1:3,4));
%     [R, t] = pnp_ak(P(:,:), q1, K, pr);
%     [R, t] = epnp_original(P(:,:), q1(:,:), K);
    [R, t] = opnp_trial(P(:,:), q1, K);
%     [R, t] = orthogonal_iterative_optimization(P(:,:), q1n);
    R
    % ppnp
%     q1n = K\q1;
%     [R, t] = ppnp(q1n', P', 1e-6);
    
    minerr = 1e6;
    minid = 0;
    P = [P;ones(1,size(P,2))];
    for i = 1:size(R,3)
        P1 = K*([R(1:3,1:3,i) t(1:3,1,i)]);
        uv1rep = P1*P;
        uv1rep = uv1rep./uv1rep(3,:);
        err = uv1rep - q1;
        avgerr = sum(diag(err'*err)) / size(q1,2);
        if avgerr < minerr
            minerr = avgerr;
            minid = i;
        end
    end
    R(:,:,minid)
    t(:,:,minid)
    
    
    

    
    
function T = fakeRT()
    euler(1) = (rand(1)*pi/2 - pi/4)*0;
    euler(2) = (rand(1)*pi/2 - pi/4)*0;
    euler(3) = (rand(1)*2*pi - pi);
    R1 = euler2rot(euler(1),euler(2),euler(3));
    t1 = rand([1,3]) * 2;
    t1 = t1';
    t1(1) = t1(1);
    t1(2) = t1(2);
    t1(3) = 1;%t1(3);
    T = [R1 t1;[0 0 0 1]];
end

function [uv1, in] = proj(T, p, K)
    P1 = K*([T(1:3,1:3) T(1:3,4)]);
    phomo = [p;ones(1,size(p,2))];
    uv1 = P1*phomo;
    uv1 = uv1./uv1(3,:);
    in = uv1(1,:) > 0 & uv1(1,:) < 321 & uv1(2,:) > 0 & uv1(2,:) < 241;
%     uv1 = uv1(:,in);
end
