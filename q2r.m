function R = q2r(q)

R = [q(1)*q(1)+q(2)*q(2)-q(3)*q(3)-q(4)*q(4) 2*(q(2)*q(3)-q(1)*q(4)) 2*(q(2)*q(4)+q(1)*q(3));...
     2*(q(2)*q(3)+q(1)*q(4)) q(1)*q(1)-q(2)*q(2)+q(3)*q(3)-q(4)*q(4) 2*(q(3)*q(4)-q(1)*q(2));...
     2*(q(2)*q(4)-q(1)*q(3)) 2*(q(3)*q(4)+q(1)*q(2)) q(1)*q(1)-q(2)*q(2)-q(3)*q(3)+q(4)*q(4)];

end