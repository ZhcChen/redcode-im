package session

import (
	"slices"
	"sync"

	"desktop-el-core/internal/state"
)

type Account struct {
	ID           string
	AccessToken  string
	RefreshToken string
	CurrentUser  *state.UserSnapshot
}

type RestoredAccount struct {
	ID           string
	AccessToken  string
	RefreshToken string
	CurrentUser  state.UserSnapshot
}

type Service struct {
	mu               sync.RWMutex
	pendingAccess    string
	pendingRefresh   string
	currentAccountID string
	accountOrder     []string
	accounts         map[string]Account
}

func New() *Service {
	return &Service{
		accounts: make(map[string]Account),
	}
}

func (s *Service) Set(accessToken, refreshToken string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.pendingAccess = accessToken
	s.pendingRefresh = refreshToken
}

func (s *Service) SetCurrentUser(user state.UserSnapshot) {
	s.mu.Lock()
	defer s.mu.Unlock()

	userCopy := user
	accountID := user.ID
	account := s.accounts[accountID]
	account.ID = accountID
	account.CurrentUser = &userCopy
	if s.pendingAccess != "" || s.pendingRefresh != "" {
		account.AccessToken = s.pendingAccess
		account.RefreshToken = s.pendingRefresh
	}
	s.accounts[accountID] = account
	s.appendAccountOrderLocked(accountID)
	s.currentAccountID = accountID
	s.pendingAccess = ""
	s.pendingRefresh = ""
}

func (s *Service) Clear() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.pendingAccess = ""
	s.pendingRefresh = ""
	s.currentAccountID = ""
	s.accountOrder = nil
	s.accounts = make(map[string]Account)
}

func (s *Service) Restore(accounts []RestoredAccount, currentAccountID string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	nextAccounts := make(map[string]Account, len(accounts))
	nextOrder := make([]string, 0, len(accounts))
	for _, restored := range accounts {
		accountID := restored.ID
		if accountID == "" {
			accountID = restored.CurrentUser.ID
		}
		if accountID == "" {
			continue
		}

		userCopy := restored.CurrentUser
		nextAccounts[accountID] = Account{
			ID:           accountID,
			AccessToken:  restored.AccessToken,
			RefreshToken: restored.RefreshToken,
			CurrentUser:  &userCopy,
		}
		nextOrder = append(nextOrder, accountID)
	}

	s.accounts = nextAccounts
	s.accountOrder = nextOrder
	s.pendingAccess = ""
	s.pendingRefresh = ""
	s.currentAccountID = ""

	if len(nextOrder) == 0 {
		return false
	}

	if _, ok := nextAccounts[currentAccountID]; ok {
		s.currentAccountID = currentAccountID
		return true
	}

	s.currentAccountID = nextOrder[0]
	return true
}

func (s *Service) Switch(accountID string) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.accounts[accountID]; !ok {
		return false
	}

	s.currentAccountID = accountID
	s.pendingAccess = ""
	s.pendingRefresh = ""
	return true
}

func (s *Service) RemoveCurrent() bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.currentAccountID == "" {
		s.pendingAccess = ""
		s.pendingRefresh = ""
		return false
	}

	delete(s.accounts, s.currentAccountID)
	s.accountOrder = slices.DeleteFunc(s.accountOrder, func(accountID string) bool {
		return accountID == s.currentAccountID
	})
	s.pendingAccess = ""
	s.pendingRefresh = ""

	if len(s.accountOrder) == 0 {
		s.currentAccountID = ""
		return false
	}

	s.currentAccountID = s.accountOrder[0]
	return true
}

func (s *Service) CurrentAccountID() string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.currentAccountID
}

func (s *Service) AccessToken() string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if account, ok := s.currentAccountLocked(); ok {
		return account.AccessToken
	}
	return s.pendingAccess
}

func (s *Service) RefreshToken() string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if account, ok := s.currentAccountLocked(); ok {
		return account.RefreshToken
	}
	return s.pendingRefresh
}

func (s *Service) CurrentUser() *state.UserSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()

	account, ok := s.currentAccountLocked()
	if !ok || account.CurrentUser == nil {
		return nil
	}

	userCopy := *account.CurrentUser
	return &userCopy
}

func (s *Service) AccountsSnapshot() []state.AccountSnapshot {
	s.mu.RLock()
	defer s.mu.RUnlock()

	snapshots := make([]state.AccountSnapshot, 0, len(s.accountOrder))
	for _, accountID := range s.accountOrder {
		account, ok := s.accounts[accountID]
		if !ok || account.CurrentUser == nil {
			continue
		}

		snapshots = append(snapshots, state.AccountSnapshot{
			ID:          accountID,
			DisplayName: buildDisplayName(account.CurrentUser),
		})
	}

	return snapshots
}

func (s *Service) currentAccountLocked() (Account, bool) {
	account, ok := s.accounts[s.currentAccountID]
	return account, ok
}

func (s *Service) appendAccountOrderLocked(accountID string) {
	for _, existing := range s.accountOrder {
		if existing == accountID {
			return
		}
	}
	s.accountOrder = append(s.accountOrder, accountID)
}

func buildDisplayName(user *state.UserSnapshot) string {
	if user == nil {
		return ""
	}
	if user.Nickname != nil && *user.Nickname != "" {
		return *user.Nickname
	}
	if user.Username != "" {
		return user.Username
	}
	return user.ID
}
