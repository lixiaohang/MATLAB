function dsicrete_trajectory_regression_on_manifold
    if ismac
        addpath './SOn_regression-master/'
        addpath './SOn_regression-master/STL'
    else
        addpath './SOn_regression-master\SOn_regression-master/'
        addpath './jiachao/'
    end
    clc;close all;clear all;
    
    % Example 2: load from mat file
    data = load('controlpoints.mat');
    n = data.n;
    N = data.N;
    p = data.p;

    % For each control point, pick a weight (positive number). A larger value
    % means the regression curve will pass closer to that control point.
    w = ones(N, 1);

    %% Define parameters of the discrete regression curve

    % The curve has Nd points on SO(n)
    Nd = 50;

    % Each control point attracts one particular point of the regression curve.
    % Specifically, control point k (in 1:N) attracts curve point s(k).
    % The vector s of length N usually satsifies:
    % s(1) = 1, s(end) = Nd and s(k+1) > s(k).
    s = round(linspace(1, Nd, N));

    % Time interval between two discretization points of the regression curve.
    % This is only used to fix a scaling. It is useful in particular so that
    % other parameter values such as w, lambda and mu (see below) have the same
    % sense even when the discretization parameter Nd is changed.
    delta_tau = 1/(Nd-1);

    % Weight of the velocity regularization term (nonnegative). The larger it
    % is, the more velocity along the discrete curve is penalized. A large
    % value usually results in a shorter curve.
    lambda = 0;

    % Weight of the acceleration regularization term (nonnegative). The larger
    % it is, the more acceleration along the discrete curve is penalized. A
    % large value usually results is a 'straighter' curve (closer to a
    % geodesic.)
    mu = 0;%1e-2;%1e-2;

    %% Pack all data defining the regression problem in a problem structure.
    problem.n = n;
    problem.N = N;
    problem.Nd = Nd;
    problem.p = p;
    problem.s = s;
    problem.w = w;
    problem.delta_tau = delta_tau;
    problem.lambda = lambda;
    problem.mu = mu;

    %% Call the optimization procedure to compute the regression curve.

    % Compute an initial guess for the curve. If this step is omitted, digress
    % (below) will compute one itself. X0 is a 3D matrix of size n x n x Nd,
    % such that each slice X0(:, :, k) is a rotation matrix.
    %
    X0 = initguess(problem);
    

    %% my part
    N1 = problem.N;
    N2 = problem.Nd;
    indices =  problem.s;
    tau = problem.delta_tau;
    miu = problem.mu;
    
    Rdata = zeros(3,3*N1);
    Rreg = zeros(3,3*N2);
    
    % fill in data to Rdata
    for i = 1:N1
        Rdata(:,i*3-2:i*3) = X0(:,:,indices(i));
    end
    for i = 1:N2
        Rreg(:,i*3-2:i*3) = X0(:,:,i);%expSO3(rand(3,1));
    end
    
    % initialize with piecewise geodesic path using park's method
    
    % start optimization
    iter = 1;
    maxiter = 500;
    
    oldcost = -1e6;
    newcost = 1e6;
    
    tol1 = 1e-5;
    
    % seems without trust-region, parallel update will be oscillate.
    % try with sequential update
    % try with quasi-parallel update
    cheeseboard_id = ones(1,N2);
%     cheeseboard_id(2:2:N2) = 0;
    cheeseboard_id = logical(cheeseboard_id);% todo, I think I need to use the parallel transport for covariant vector
        
    tr = 1;
    
%     Rreg = traj_smoothing_via_jc(Rreg, indices, 100000, 100);
        
%     [speed0, acc0] = compute_profiles(problem, X0);
    options = optimoptions('quadprog','MaxIterations',100,'OptimalityTolerance',1e-3,'StepTolerance',1e-3,'Display','off');
    tic
    while iter < maxiter
%         xi = data_term_error(Rdata,Rreg,indices);
%         v = numerical_diff_v(Rreg);
%         newcost = cost(xi,v,tau,lambda,miu);
%         
%         if abs(newcost - oldcost) < tol1
%             break;
%         end
%         oldcost = newcost;
%         
%         % compute gradient, batch optimization
%         % here, I will compute graduate for all so3s and then update as a
%         % batch. I think perhaps sequencial update could be another option
%         % since somehow this is a nonconvex optimization, no global minimum
%         % is guaranteed.
%         [LHS, RHS] = batch_sol(xi, v, indices, tau, lambda, miu, N2, Rreg);
%         dxis = -LHS\RHS;
%         % update
%         for j = 1:N2
%             dxi = dxis(j*3-2:j*3).*cheeseboard_id(j);
%             if norm(dxi) > tr
%                 dxi = dxi ./ norm(dxi) .* tr;
%             end
%             Rreg(:,j*3-2:j*3) = Rreg(:,j*3-2:j*3) * expSO3(dxi);
%         end
%         cheeseboard_id = ~cheeseboard_id;
        
        % sequential update
        newcost = 0;
        ids = randperm(N2,N2);
        for j = 1:N2
            id = j;%ids(j);
            xi = data_term_error(Rdata,Rreg,indices,id);
            v = numerical_diff_v(Rreg,id);
            dxi = seq_sol(xi, v, indices, tau, lambda, miu, N2, id,Rreg,options);
%             dxis = -LHS(id*3-2:id*3,id*3-2:id*3)\RHS(id*3-2:id*3);
            % 
            if norm(dxi) > tr
                dxi = dxi ./ norm(dxi) .* tr;
            end
            dxis(:,id)=dxi;
%             Rreg(:,id*3-2:id*3) = Rreg(:,id*3-2:id*3) * expSO3(dxi);
%             if norm(dxis) > newcost
%                 newcost = norm(dxis);
%             end
        end
        for j = 1:N2
            id = j;
            dxi = dxis(:,id).*cheeseboard_id(id);
            Rreg(:,id*3-2:id*3) = Rreg(:,id*3-2:id*3) * expSO3(Rreg(:,id*3-2:id*3)'*dxi);
        end
%         cheeseboard_id = ~cheeseboard_id;
        
        %%%% new method of expansion
%         dxis = zeros(3,N2);
%         [LHS, RHS] = seq_sol2(Rdata,Rreg,indices,tau,lambda,miu,N2);
%         dxis = -LHS\RHS;
% %         ids = randperm(N2,N2);
% %         for j = 1:N2
% %             id = ids(j);
% %             dxi = -LHS\RHS;
% %             if norm(dxi) > tr
% %                 dxi = dxi ./ norm(dxi) .* tr;
% %             end
% %             Rreg(:,id*3-2:id*3) = Rreg(:,id*3-2:id*3) * expSO3(dxi);
% %             dxis(:,id)=dxi;
% %         end
%         for j = 1:N2
%             id = j;
%             dxi = dxis(id*3-2:id*3).*cheeseboard_id(id);
%             if norm(dxi) > tr
%                 dxi = dxi ./ norm(dxi) .* tr;
%             end
%             Rreg(:,id*3-2:id*3) = Rreg(:,id*3-2:id*3) * expSO3(dxi);
%         end
%         cheeseboard_id = ~cheeseboard_id;

        % doesnot work
%         Rreg = opt_regression(Rdata, indices, tau, lambda, miu, N2);
        
        xi = data_term_error(Rdata,Rreg,indices);
        v = numerical_diff_v(Rreg);
        newcost = cost(xi,v,tau,lambda,miu);
        newcosts(iter) = newcost;
        if abs(newcost - oldcost) < tol1
            break;
        end
        oldcost = newcost;
        
        % TODO, do we need to check the norm of the gradient and exit if
        % the norm of gradient is lower than a threshold.
        
        iter = iter + 1;
        disp(iter);
    end
    toc
    
    figure(7);
    plot(newcosts,'r-o','LineWidth',2);
    
    figure(1);
    plotrotations(X0(:, :, 1:4:Nd));
    view(0, 0);
    
    for i = 1:N2
        X1(:,:,i) = Rreg(:,i*3-2:i*3);
    end

    figure(2);
    plotrotations(X1(:, :, 1:4:Nd));
    view(0, 0);
    
    figure(3);
    plotrotations(X0(:, :, indices));
    view(0, 0);
    figure(4);
    plotrotations(X1(:, :, indices));
    view(0, 0);
    
    
    [speed0, acc0] = compute_profiles(problem, X0);
    [speed1, acc1] = compute_profiles(problem, X1);

    % Passage time of each point on the discrete curves.
    time = problem.delta_tau*( 0 : (problem.Nd-1) );

    figure(5);

    subplot(1, 2, 1);
    plot(1:N2,speed0,1:N2,speed1);
%     plot(time, speed0, time, speed1);
    title('Speed of initial curve and optimized curve');
    xlabel('Time');
    ylabel('Speed');
    legend('Initial curve', 'Optimized curve', 'Location', 'SouthEast');
    pbaspect([1.6, 1, 1]);

    subplot(1, 2, 2);
    plot(1:N2,acc0,1:N2,acc1);
%     plot(time, acc0, time, acc1);
    title('Acceleration of initial curve and optimized curve');
    xlabel('Time');
    ylabel('Acceleration');
    legend('Initial curve', 'Optimized curve', 'Location', 'NorthWest');
    pbaspect([1.6, 1, 1]);

    ylim([0, 100]);
    
end

function [AtA,Atb] = calcAb(a,b,c,type)
    if type == 1
        bc = logSO3(expSO3(b)'*expSO3(c));
        Jrinv = rightJinv(a);
        s = hat(b);
        A = Jrinv - 0.5.*s*Jrinv;
        b = bc+a-b-0.5.*s*a;
    elseif type == 2
        Jrinv = rightJinv(b);
        sa = hat(a);
        sc = hat(c);
        A = -Jrinv + 0.5.*sa*Jrinv - Jrinv + 0.5.*sc*Jrinv;
        b = c+a-b-b+0.5.*sa*b+0.5.*sc*b;
    else
        ba = logSO3(expSO3(b)'*expSO3(a));
        Jrinv = rightJinv(c);
        s = hat(b);
        A = Jrinv - 0.5.*s*Jrinv;
        b = ba+c-b-0.5.*s*c;
    end
    AtA = A'*A;
    Atb = A'*b;
end

function [LHS, RHS] = seq_sol2(Rdata,Rreg,indices,tau,lambda,miu,N,varargin)
    % another way of approximating by expanding around R.
    if isempty(varargin) 
        so3reg = zeros(3,N);
        for i = 1:N
            so3reg(:,i)=logSO3(Rreg(:,i*3-2:i*3));
        end
        so3data = zeros(3,round(size(Rdata,2)/3));
        for i = 1:length(indices)
            so3data(:,i)=logSO3(Rdata(:,i*3-2:i*3));
        end

        lhs = zeros(3,3,N);
        rhs = zeros(3,N);

        % fist deal with term 1
        for i = 1:length(indices)
            Jr = rightJinv(so3reg(:,indices(i)));% * Rreg(:,indices(i)*3-2:indices(i)*3);
            A = (Jr-0.5.*hat(so3data(:,i))*Jr);
            b = so3reg(:,indices(i))-so3data(:,i)-0.5.*hat(so3data(:,i))*so3reg(:,indices(i));
            lhs(:,:,indices(i)) = lhs(:,:,indices(i)) + A'*A;
            rhs(:,indices(i)) = rhs(:,indices(i)) + A'*b;
        end

        c1 = lambda / tau;
        if lambda == 0
        end

        % third term
        c2 = miu / (tau^3);

        % end points
        [AtA,Atb] = calcAb(so3reg(:,1),so3reg(:,2),so3reg(:,3),1);
        lhs(:,:,1) = lhs(:,:,1) + AtA.*c2;
        rhs(:,1) = rhs(:,1) + Atb.*c2;

        [AtA,Atb] = calcAb(so3reg(:,end-2),so3reg(:,end-1),so3reg(:,end),3);
        lhs(:,:,end) = lhs(:,:,end) + AtA.*c2;
        rhs(:,end) = rhs(:,end) + Atb.*c2;

        % 2, two times
        [AtA,Atb] = calcAb(so3reg(:,1),so3reg(:,2),so3reg(:,3),2);
        lhs(:,:,2) = lhs(:,:,2) + AtA.*c2;
        rhs(:,2) = rhs(:,2) + Atb.*c2;

        [AtA,Atb] = calcAb(so3reg(:,2),so3reg(:,3),so3reg(:,4),1);
        lhs(:,:,2) = lhs(:,:,2) + AtA.*c2;
        rhs(:,2) = rhs(:,2) + Atb.*c2;

        % end - 1, two times
        [AtA,Atb] = calcAb(so3reg(:,end-2),so3reg(:,end-1),so3reg(:,end),2);
        lhs(:,:,end-1) = lhs(:,:,end-1) + AtA.*c2;
        rhs(:,end-1) = rhs(:,end-1) + Atb.*c2;

        [AtA,Atb] = calcAb(so3reg(:,end-3),so3reg(:,end-2),so3reg(:,end-1),3);
        lhs(:,:,end-1) = lhs(:,:,end-1) + AtA.*c2;
        rhs(:,end-1) = rhs(:,end-1) + Atb.*c2;

        % 3 times
        for i = 3:N-2
            [AtA,Atb] = calcAb(so3reg(:,i-1),so3reg(:,i),so3reg(:,i+1),2);
            lhs(:,:,i) = lhs(:,:,i) + AtA.*c2;
            rhs(:,i) = rhs(:,i) + Atb.*c2;

            [AtA,Atb] = calcAb(so3reg(:,i),so3reg(:,i+1),so3reg(:,i+2),1);
            lhs(:,:,i) = lhs(:,:,i) + AtA.*c2;
            rhs(:,i) = rhs(:,i) + Atb.*c2;

            [AtA,Atb] = calcAb(so3reg(:,i-2),so3reg(:,i-1),so3reg(:,i),3);
            lhs(:,:,i) = lhs(:,:,i) + AtA.*c2;
            rhs(:,i) = rhs(:,i) + Atb.*c2;
        end

        if c1 == 0 && c2 == 0
            ii = 1:N;
            ii(indices) = [];
            for i = 1:length(ii)
                lhs(:,:,ii(i)) = eye(3);
            end
        end

        LHS = spblkdiag(lhs);
        RHS = rhs(:);
    else
        LHS = zeros(3,3);
        RHS = zeros(3,1);
        
        id = varargin{1};
        so3c = logSO3(Rreg(:,id*3-2:id*3));
        
        mid = find(indices==id,1);
        if ~isempty(mid)
            so3data=logSO3(Rdata(:,mid*3-2:mid*3));
            Jr = rightJinv(so3c);% * Rreg(:,indices(i)*3-2:indices(i)*3);
            A = (Jr-0.5.*hat(so3data)*Jr);
            b = so3c-so3data-0.5.*hat(so3data)*so3c;
            LHS = LHS + A'*A;
            RHS = RHS + A'*b;
        end
        
        c1 = lambda / tau;
        if lambda == 0
        end

        % third term
        c2 = miu / (tau^3);
        
        if id == 1
            so3cc = logSO3(Rreg(:,4:6));
            so3ccc = logSO3(Rreg(:,7:9));
            % end points
            [AtA,Atb] = calcAb(so3c,so3cc,so3ccc,1);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
        elseif id == N
            so3cp = logSO3(Rreg(:,end-5:end-3));
            so3cpp = logSO3(Rreg(:,end-8:end-6));
            [AtA,Atb] = calcAb(so3cpp,so3cp,so3c,3);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
        elseif id == 2
            so3cc = logSO3(Rreg(:,7:9));
            so3ccc = logSO3(Rreg(:,10:12));
            so3cp = logSO3(Rreg(:,1:3));
            % 2, two times
            [AtA,Atb] = calcAb(so3cp,so3c,so3cc,2);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;

            [AtA,Atb] = calcAb(so3c,so3cc,so3ccc,1);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
        elseif id == N-1
            so3cp = logSO3(Rreg(:,end-8:end-6));
            so3cpp = logSO3(Rreg(:,end-11:end-9));
            so3cc = logSO3(Rreg(:,end-2:end));
            [AtA,Atb] = calcAb(so3cp,so3c,so3cc,2);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
            
            [AtA,Atb] = calcAb(so3cpp,so3cp,so3c,3);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
        else
            so3cc = logSO3(Rreg(:,(id+1)*3-2:(id+1)*3));
            so3ccc = logSO3(Rreg(:,(id+2)*3-2:(id+2)*3));
            so3cp = logSO3(Rreg(:,(id-1)*3-2:(id-1)*3));
            so3cpp = logSO3(Rreg(:,(id-2)*3-2:(id-2)*3));
            
            [AtA,Atb] = calcAb(so3cp,so3c,so3cc,2);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
            
            [AtA,Atb] = calcAb(so3cpp,so3cp,so3c,3);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
            
            [AtA,Atb] = calcAb(so3c,so3cc,so3ccc,1);
            LHS = LHS + AtA.*c2;
            RHS = RHS + Atb.*c2;
        end

        if c1 == 0 && c2 == 0
            if isempty(mid)
                LHS = eye(3);
            end
        end
    end
end

function dxi = seq_sol(xi, v, indices, tau, lambda, miu, N, id,Rreg,options)
    lhs = zeros(3,3);
    rhs = zeros(3,1);
    
    if ~isempty(xi)
        Jr = rightJinv(xi);
        lhs = lhs + Jr'*Jr;
        rhs = rhs + Jr'*xi;
    end
    
    v = Rreg(:,id*3-2:id*3) * v;
    
    % second term
    % endpoints 
    c1 = lambda / tau;
    if lambda ~= 0
        if id == 1
            Jr = rightJinv(v(:,1));
            lhs = lhs + Jr'*Jr.*c1;
            rhs = rhs + Jr'*(v(:,1)).*c1;
        elseif id == N
            Jr = rightJinv(v(:,end));
            lhs = lhs + Jr'*Jr.*c1;
            rhs = rhs + Jr'*(v(:,end)).*c1;
        else
            if id == 2
                id1 = 1;
                id2 = 2;
            else
                id1 = 2;
                id2 = 3;
            end
                
            Jr1 = rightJinv(v(:,id1));
            Jr2 = rightJinv(v(:,id2));
            A1 = Jr1'*Jr1;
            b1 = Jr1'*v(:,id1);
            A2 = Jr2'*Jr2;
            b2 = Jr2'*(v(:,id2));
            lhs = lhs + (A1+A2).*c1;
            rhs = rhs + (b1+b2).*c1;
        end
    end
    
    % third term
    c2 = miu / (tau^3);
    %% new, use parallel transport and unify all +/-
    ss = 1;
    
    
%     Aineq = zeros(3*3,3);
%     bineq = zeros(3*3,1);
%     dummy1 = 0;
    
    if id == 1
        Jr = rightJinv(v(:,1));% * Rreg(:,1:3)';
        lhs = lhs + Jr'*Jr.*c2;
        rhs = rhs + Jr'*(v(:,1)+v(:,2).*ss).*c2;
        
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,1)+v(:,2);
        
    elseif id == N
        Jr = rightJinv(v(:,end));% * Rreg(:,end-2:end)';
        lhs = lhs + Jr'*Jr.*c2;
        rhs = rhs + Jr'*(v(:,end-1).*ss+v(:,end)).*c2;
        
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,end-1)+v(:,end);
    elseif id == 2
        % 2, two times
        Jr1 = rightJinv(v(:,1));% * Rreg(:,4:6)'; 
        Jr2 = rightJinv(v(:,2));% * Rreg(:,4:6)';
        A1 = Jr1+Jr2; 
        b1 = A1'*(v(:,2)+v(:,1));A1 = A1'*A1;
    
        A2 = Jr2'*Jr2;
        b2 = Jr2'*(v(:,3).*ss+v(:,2));

        lhs = lhs + (A1+A2).*c2;
        rhs = rhs + (b1+b2).*c2;
        
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr1+Jr2;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,2)+v(:,1);
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr2;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,3)+v(:,2);
    elseif id == N-1
        % end - 1, two times
        Jr1 = rightJinv(v(:,end-1));% * Rreg(:,end-5:end-3)'; 
        Jr2 = rightJinv(v(:,end));% * Rreg(:,end-5:end-3)';
        A1 = Jr1+Jr2; 
        b1 = A1'*(v(:,end)+v(:,end-1));A1 = A1'*A1;

        A2 = Jr1'*Jr1;
        b2 = Jr1'*(v(:,end-2).*ss+v(:,end-1));

        lhs = lhs + (A1+A2).*c2;
        rhs = rhs + (b1+b2).*c2;
        
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr1+Jr2;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,end)+v(:,end-1);
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr1;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,end-2)+v(:,end-1);
    else
        % 3 times
        Jr1 = rightJinv(v(:,2));% * Rreg(:,id*3-2:id*3)';
        Jr2 = rightJinv(v(:,3));% * Rreg(:,id*3-2:id*3)';
        A1 = Jr1+Jr2;
        b1 = A1'*(v(:,3) + v(:,2));A1 = A1'*A1;

        A2 = Jr1;
        b2 = A2'*(v(:,2)+v(:,1).*ss);A2 = A2'*A2;

        A3 = Jr2;
        b3 = A3'*(v(:,4).*ss+v(:,3));A3 = A3'*A3;

        lhs = lhs + (A1+A2+A3).*c2;
        rhs = rhs + (b1+b2+b3).*c2;
        
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr1+Jr2;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,3) + v(:,2);
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr1;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,2)+v(:,1);
%         
%         dummy1 = dummy1 + 1;
%         Aineq(dummy1*3-2:dummy1*3,:) = Jr2;
%         bineq(dummy1*3-2:dummy1*3,:) = v(:,4)+v(:,3);
    end

    if c1 == 0 && c2 == 0
        index = find(indices == id,1);
        if isempty(index)
            lhs = eye(3);
        end
    end
    
    LHS = lhs;
    RHS = rhs;
    
    dxi = -LHS\RHS;% unconstrained optimization
    
%     %% what if I use constrained optimization.
%     Aineq(dummy1*3+1:end,:) = [];
%     bineq(dummy1*3+1:end,:) = [];
%     amax = 0.01;%sqrt(1000)/2*tau*tau;
%     Aineq2 = [Aineq;-Aineq];
%     bineq2 = [amax-bineq;amax+bineq];
% %     
%     dxi = quadprog(2.*LHS,2*RHS',Aineq2,bineq2,[],[],[],[],[],options);
end

function [LHS, RHS] = batch_sol(xi, v, indices, tau, lambda, miu, N, Rreg)
    lhs = zeros(3,3,N);
    rhs = zeros(3,N);
    
    % fist deal with term 1
    for i = 1:length(indices)
        Jr = rightJinv(xi(:,i));% * Rreg(:,indices(i)*3-2:indices(i)*3);
        lhs(:,:,indices(i)) = lhs(:,:,indices(i)) + Jr'*Jr;
        rhs(:,indices(i)) = rhs(:,indices(i)) + Jr'*xi(:,i);
    end
    
    % second term
    % endpoints 
    c1 = lambda / tau;
    if lambda ~= 0
        Jr = rightJinv(-v(:,1)) * Rreg(:,1:3);
        lhs(:,:,1) = lhs(:,:,1) + Jr'*Jr.*c1;
        rhs(:,1) = rhs(:,1) + Jr'*(-v(:,1)).*c1;

        Jr = rightJinv(v(:,end)) * Rreg(:,end-2:end);
        lhs(:,:,end) = lhs(:,:,end) + Jr'*Jr.*c1;
        rhs(:,end) = rhs(:,end) + Jr'*(v(:,end)).*c1;

        for i = 2:N-1
            Jr1 = rightJinv(v(:,i-1)) * Rreg(:,i*3-2:i*3);
            Jr2 = rightJinv(-v(:,i)) * Rreg(:,i*3-2:i*3);
            A1 = Jr1'*Jr1;
            b1 = Jr1'*v(:,i-1);
            A2 = Jr2'*Jr2;
            b2 = Jr2'*(-v(:,i));
            lhs(:,:,i) = lhs(:,:,i) + (A1+A2).*c1;
            rhs(:,i) = rhs(:,i) + (b1+b2).*c1;
        end
    end
    
    
    % third term
    c2 = miu / (tau^3);
    % end points
    Jr = rightJinv(-v(:,1));% * Rreg(:,1:3);
    lhs(:,:,1) = lhs(:,:,1) + Jr'*Jr.*c2;
    rhs(:,1) = rhs(:,1) + Jr'*(-v(:,1)+v(:,2)).*c2;
    
    Jr = rightJinv(v(:,end));% * Rreg(:,end-2:end);
    lhs(:,:,end) = lhs(:,:,end) + Jr'*Jr.*c2;
    rhs(:,end) = rhs(:,end) + Jr'*(-v(:,end-1)+v(:,end)).*c2;
    
    % 2, two times
    Jr1 = rightJinv(v(:,1));% * Rreg(:,1:3); 
    Jr2 = rightJinv(-v(:,2));% * Rreg(:,1:3);
    A1 = Jr1+Jr2; 
    b1 = A1'*(-v(:,2)+v(:,1));A1 = A1'*A1;
    
    A2 = Jr2'*Jr2;
    b2 = Jr2'*(v(:,3)-v(:,2));
    
    lhs(:,:,2) = lhs(:,:,2) + (A1+A2).*c2;
    rhs(:,2) = rhs(:,2) + (b1+b2).*c2;
    % end - 1, two times
    Jr1 = rightJinv(v(:,end-1));% * Rreg(:,1:3); 
    Jr2 = rightJinv(-v(:,end));% * Rreg(:,1:3);
    A1 = Jr1+Jr2; 
    b1 = A1'*(-v(:,end)+v(:,end-1));A1 = A1'*A1;
    
    A2 = Jr1'*Jr1;
    b2 = Jr1'*(-v(:,end-2)+v(:,end-1));
    
    lhs(:,:,end-1) = lhs(:,:,end-1) + (A1+A2).*c2;
    rhs(:,end-1) = rhs(:,end-1) + (b1+b2).*c2;
    
    % 3 times
    for i = 3:N-2
        Jr1 = rightJinv(v(:,i-1));% * Rreg(:,i*3-2:i*3);
        Jr2 = rightJinv(-v(:,i));% * Rreg(:,i*3-2:i*3);
        A1 = Jr1+Jr2;
        b1 = A1'*(-v(:,i) + v(:,i-1));A1 = A1'*A1;
        
        A2 = Jr1;
        b2 = A2'*(v(:,i-1)-v(:,i-2));A2 = A2'*A2;
        
        A3 = Jr2;
        b3 = A3'*(v(:,i+1)-v(:,i));A3 = A3'*A3;
        
        lhs(:,:,i) = lhs(:,:,i) + (A1+A2+A3).*c2;
        rhs(:,i) = rhs(:,i) + (b1+b2+b3).*c2;
    end
    
    if c1 == 0 && c2 == 0
        ii = 1:N;
        ii(indices) = [];
        for i = 1:length(ii)
            lhs(:,:,ii(i)) = eye(3);
        end
    end
    
    LHS = spblkdiag(lhs);
    RHS = rhs(:);
end

function xi = data_term_error(Rdata,Rreg,indices,varargin)
    if nargin == 3
        xi = zeros(3,length(indices));
        for i = 1:length(indices)
            ii = indices(i);
            xi(:,i) = logSO3(Rdata(:,(i*3-2):i*3)'*Rreg(:,(ii*3-2):ii*3));
            xi(:,i) = para_trans(Rdata(:,(i*3-2):i*3),Rreg(:,(ii*3-2):ii*3),xi(:,i));
        end
    else
        id = find(indices == varargin{1},1);
        if isempty(id) 
            xi = [];
        else
            ii = indices(id);
            xi = logSO3(Rdata(:,(id*3-2):id*3)'*Rreg(:,(ii*3-2):ii*3));
            xi = para_trans(Rdata(:,(id*3-2):id*3),Rreg(:,(ii*3-2):ii*3),xi);
        end
    end
end

function v = numerical_diff_v(Rreg,varargin)
    N = round(size(Rreg,2)/3);
    if nargin == 1
        v = zeros(3,N-1);
        for i = 1:N-1
            v(:,i) = logSO3(Rreg(:,(i*3-2):i*3)'*Rreg(:,(i*3+1):(i*3+3)));
        end
    else
        i = varargin{1};
        if i == 1
            % tangent plane 2
            v(:,1) = logSO3(Rreg(:,(i*3+1):i*3+3)'*Rreg(:,(i*3-2):(i*3)));% 2 -- 1            
            v(:,2) = logSO3(Rreg(:,(i*3+1):i*3+3)'*Rreg(:,(i*3+4):(i*3+6)));% 2 -- 3
            
            v(:,1) = para_trans(Rreg(:,(i*3+1):i*3+3),Rreg(:,(i*3-2):i*3),v(:,1));% tgt2 to 1
            v(:,2) = para_trans(Rreg(:,(i*3+1):i*3+3),Rreg(:,(i*3-2):i*3),v(:,2));% tgt2 to 1

            % old code
%             v(:,1) = logSO3(Rreg(:,(i*3-2):i*3)'*Rreg(:,(i*3+1):(i*3+3)));
%             v(:,2) = logSO3(Rreg(:,(i*3+1):i*3+3)'*Rreg(:,(i*3+4):(i*3+6)));
        elseif i == N
            v(:,1) = logSO3(Rreg(:,(i*3-5):i*3-3)'*Rreg(:,(i*3-8):(i*3-6)));%e-1 -- e-2
            v(:,2) = logSO3(Rreg(:,(i*3-5):i*3-3)'*Rreg(:,(i*3-2):(i*3)));%e-1 -- e
            
            v(:,1) = para_trans(Rreg(:,(i*3-5):i*3-3),Rreg(:,(i*3-2):i*3),v(:,1));% e-1 -- e
            v(:,2) = para_trans(Rreg(:,(i*3-5):i*3-3),Rreg(:,(i*3-2):i*3),v(:,2));
            
%             v(:,1) = logSO3(Rreg(:,(i*3-8):i*3-6)'*Rreg(:,(i*3-5):(i*3-3)));
%             % tangent plane n-1
%             v(:,2) = logSO3(Rreg(:,(i*3-5):i*3-3)'*Rreg(:,(i*3-2):(i*3)));
%             
        elseif i == 2
            % little trick, 1--2 parallel to 2 equals to -(1--2)
            v(:,1) = -logSO3(Rreg(:,(i*3-2):(i*3))'*Rreg(:,(i*3-5):(i*3-3)));% 1 -- 2 pt to 2
            v(:,2) = -logSO3(Rreg(:,(i*3-2):(i*3))'*Rreg(:,(i*3+1):(i*3+3)));% 3 -- 2 pt to 2
            v(:,3) = logSO3(Rreg(:,(i*3+1):i*3+3)'*Rreg(:,(i*3+4):(i*3+6)));% 3 -- 4
            
            v(:,3) = para_trans(Rreg(:,(i*3+1):i*3+3),Rreg(:,(i*3-2):i*3),v(:,3));% pt to 2
        elseif i == N-1
            v(:,1) = logSO3(Rreg(:,(i*3-5):i*3-3)'*Rreg(:,(i*3-8):(i*3-6)));% e-2 -- e-3
            v(:,2) = -logSO3(Rreg(:,(i*3-2):i*3)'*Rreg(:,(i*3-5):(i*3-3)));% e-2 -- e-1 to e-1
            v(:,3) = -logSO3(Rreg(:,(i*3-2):i*3)'*Rreg(:,(i*3+1):(i*3+3)));% e -- e-1 to e-1
            
            v(:,1) = para_trans(Rreg(:,(i*3-5):(i*3-3)),Rreg(:,(i*3-2):i*3),v(:,1));% pt from e-2 to e-1
        else
            v(:,1) = logSO3(Rreg(:,(i*3-5):i*3-3)'*Rreg(:,(i*3-8):(i*3-6)));% i-1 -- i-2
            v(:,2) = logSO3(Rreg(:,(i*3-5):i*3-3)'*Rreg(:,(i*3-2):(i*3))); % i-1 -- i
            v(:,3) = logSO3(Rreg(:,(i*3+1):i*3+3)'*Rreg(:,(i*3-2):(i*3))); % i+1 -- i
            v(:,4) = logSO3(Rreg(:,(i*3+1):i*3+3)'*Rreg(:,(i*3+4):(i*3+6))); % i+1 -- i+2
            
            v(:,1) = para_trans(Rreg(:,(i*3-5):(i*3-3)),Rreg(:,(i*3-2):i*3),v(:,1));% pt from i-1 to i
            v(:,2) = para_trans(Rreg(:,(i*3-5):(i*3-3)),Rreg(:,(i*3-2):i*3),v(:,2));% pt from i-1 to i
            v(:,3) = para_trans(Rreg(:,(i*3+1):(i*3+3)),Rreg(:,(i*3-2):i*3),v(:,3));% pt from i+1 to i
            v(:,4) = para_trans(Rreg(:,(i*3+1):(i*3+3)),Rreg(:,(i*3-2):i*3),v(:,4));% pt from i+1 to i
        end
    end
end


function y = cost(xi,v,tau,lambda,miu)
    % cost term 1, data cost
    cost1 = sum(vecnorm(xi,2).^2.*2);
    
    % cost term 2, first order smooth cost, integrate with trapezoidal
    % rule, consistent with Boumal's paper. TODO change in paper.
    N = size(v,2)+1;
    wv = [1 ones(1,N-2)];
    cost2 = sum(vecnorm(v,2).^2.*(2/tau).*wv);
    
    % cost term 3, second order smooth cost, integrate with trapezoidal
    % rule
    a = zeros(3,N-2);
    for i = 2:N-1
        a(:,i-1)=v(:,i)-v(:,i-1);
    end
    cost3 = sum(vecnorm(a,2).^2.*(2/tau^3));
    
    y = cost1 * 0.5 + cost2 * 0.5 * lambda + cost3 * 0.5 * miu;
end
