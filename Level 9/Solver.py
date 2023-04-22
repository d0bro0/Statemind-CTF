# r, s2, z2, s1, z1
r = 48708829000562269905876821210175722369626766479178582447676249779003440956185

s1 = 60077470740015778015728026926384856323577744015343895233974187170143505500512

s2 = 66568942085538672592149186888899205386385323479793141445347603047663416242401

z1 = 39746421223726488866046390179787522663525993347501961555638706646684060652389

z2 = 12733668332397625975119874398864940098315888208887780570681982903282076659984


# prime order p
p = 0xfffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141

# based on Fermat's Little Theorem
# works only on prime n

def inverse_mod(a, n):
    return pow(a, n-2, n)

k = (z1 - z2) * inverse_mod(s1 - s2, p) % p             # derive k for s1 - s2
pk = (s1 * k - z1) * inverse_mod(r, p) % p              # derive private key

print('private key = {:x}'.format(pk))
print('')
