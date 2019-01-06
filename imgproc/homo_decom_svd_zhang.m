function varargout = homo_decom_svd_zhang(varargin)
%% decompose homography matrix using olivier algo.
    H = varargin{1};
    format long;
    
    [VE, EE] = eig(H'*H);
    lambda1 = EE(2,2);lambda3 = EE(1,1);lambda2 = EE(3,3);
    v1 = VE(:,2);v3 = EE(:,1);v2 = EE(:,3);
    
    %% SVD 
    [U,S,V] = svd(H);
    
    rho2 = S(1,1);rho1 = S(2,2);rho3 = S(3,3);
    u2 = V(:,1);u1 = V(:,2);u3 = V(:,3);
    
    if abs(lambda2-lambda1) > 1e-6 && abs(lambda1 - lambda3) > 1e-6
        %% case 1
        %% scale
        l = 1 ./ rho1;
        rho2 = rho2 * l;
        rho3 = rho3 * l;
        
        k = rho2 - rho3;p = rho2*rho3 - 1;
        
        c1 = sqrt(k*k+4*(p+1));
        c2 = 2*k*(p+1);
        gamma = (-k+c1)/c2;
        theta = (-k-c1)/c2;
        
        miu = sqrt(gamma*gamma*k*k+2*gamma*p+1);
        sigma = sqrt(theta*theta*k*k+2*theta*p+1);
        
        c3 = gamma - theta;
        t0(:,1) = (miu*u2-sigma*u3)./c3;
        t0(:,2) = -(miu*u2-sigma*u3)./c3;
        t0(:,3) = (miu*u2+sigma*u3)./c3;
        t0(:,4) = -(miu*u2+sigma*u3)./c3;
        
        cv1 = gamma * sigma * u3 - theta*miu*u2;
        cv2 = gamma * sigma * u3 + theta*miu*u2;
        
        n(:,1) = cv1./c3;
        n(:,2) = -cv1./c3;
        n(:,3) = cv2./c3;
        n(:,4) = -cv2./c3;
        
       
    elseif abs(lambda1 - lambda3) < 1e-6
        k = rho2 - 1;
%         p = k;
        n(:,1) = u2;
        n(:,2) = -u2;
        
        t0(:,1) = k*n(:,1);
        t0(:,2) = k*n(:,2);
    
        k = rho2 + 1;
        n(:,3) = u2;
        n(:,4) = -u2;
        
        t0(:,3) = -k*n(:,3);
        t0(:,4) = -k*n(:,4);
    elseif abs(lambda2 - lambda1) < 1e-6
        k = rho3 + 1;
        n(:,1) = u3;
        n(:,2) = -u3;
        t0(:,1) = -k*n(:,1);
        t0(:,2) = -k*n(:,2);
        
        k = -rho3 + 1;
        n(:,3) = u3;
        n(:,4) = -u3;
        
        t0(:,3) = -k*n(:,3);
        t0(:,4) = -k*n(:,4);
    else
        warning('Undefined');
        n(:,1) = zeros(3,1);
        t0(:,1) = zeros(3,1);
    end
    R = zeros(3,3,size(t0,2));
    for i = 1:size(t0,2)
        R(:,:,i) = H/(eye(3)+t0(:,i)*n(:,i)');
%         R(:,:,2) = H/(eye(3)+t0(:,2)*n(:,2)');
%         R(:,:,3) = H/(eye(3)+t0(:,3)*n(:,3)');
%         R(:,:,4) = H/(eye(3)+t0(:,4)*n(:,4)');
    end
    t = t0;%% unknown H, so H = 1

    %% ambiguity removing, visibility constraint
    m1 = varargin{2};
    num1 = [m1(1,1);m1(2,1);m1(3,1)];
    valid1 = zeros(1,size(t,2));
    for i = 1:size(t,2)
        if dot(num1, n(:,i)) > 0
            valid1(i) = 1;
        end
    end
    valid1 = valid1 == 1;
    Rf = R(:,:,valid1);
    tf = t(:,valid1);
    nf = n(:,valid1);
    
    varargout{1} = Rf;
    varargout{2} = tf;
    varargout{3} = nf;
end

