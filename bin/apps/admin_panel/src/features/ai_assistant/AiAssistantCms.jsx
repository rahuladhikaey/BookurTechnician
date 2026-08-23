import React, { useState, useEffect, useCallback } from 'react';
import api from '../../api/apiClient';

export default function AiAssistantCms({ auditLogAction }) {
  const [activeTab, setActiveTab] = useState('documents');
  const [documents, setDocuments] = useState([]);
  const [faqs, setFaqs] = useState([]);
  const [loading, setLoading] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [docsRes, faqsRes] = await Promise.allSettled([
        api.getAiDocs(),
        api.getAiFaqs()
      ]);
      if (docsRes.status === 'fulfilled' && docsRes.value?.data) {
        setDocuments(docsRes.value.data);
      }
      if (faqsRes.status === 'fulfilled' && faqsRes.value?.data) {
        setFaqs(faqsRes.value.data);
      }
    } catch (err) {
      console.error('Error loading AI CMS data:', err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const [showDocModal, setShowDocModal] = useState(false);
  const [editingDoc, setEditingDoc] = useState(null);
  const [docForm, setDocForm] = useState({
    category: 'Cancellation Policy',
    title: '',
    content: '',
    version: 'v1.0',
    effectiveDate: '15 Aug 2026',
    status: 'Published'
  });

  const [showFaqModal, setShowFaqModal] = useState(false);
  const [editingFaq, setEditingFaq] = useState(null);
  const [faqForm, setFaqForm] = useState({
    category: 'General',
    question: '',
    answer: '',
    status: 'Published'
  });

  // Simulator Test
  const [simQuery, setSimQuery] = useState('');
  const [simResponse, setSimResponse] = useState(null);

  // ─── DOCUMENT HANDLERS ───
  const openAddDoc = () => {
    setEditingDoc(null);
    setDocForm({
      category: 'Cancellation Policy',
      title: '',
      content: '',
      version: `v${(documents.length * 0.5 + 1).toFixed(1)}`,
      effectiveDate: '15 Aug 2026',
      status: 'Published'
    });
    setShowDocModal(true);
  };

  const openEditDoc = (doc) => {
    setEditingDoc(doc.id);
    setDocForm({
      category: doc.category,
      title: doc.title,
      content: doc.content,
      version: doc.version,
      effectiveDate: doc.effectiveDate,
      status: doc.status
    });
    setShowDocModal(true);
  };

  const handleSaveDoc = (e) => {
    e.preventDefault();
    if (editingDoc) {
      setDocuments(prev => prev.map(d => d.id === editingDoc ? {
        ...d,
        ...docForm,
        updatedAt: 'Just Now',
        updatedBy: 'Operations Admin'
      } : d));
      auditLogAction?.('AI Knowledge CMS', `Updated policy document "${docForm.title}" (${docForm.version})`);
    } else {
      const newD = {
        id: `doc_${Date.now()}`,
        ...docForm,
        updatedAt: 'Just Now',
        updatedBy: 'Operations Admin'
      };
      setDocuments(prev => [newD, ...prev]);
      auditLogAction?.('AI Knowledge CMS', `Published new policy document "${newD.title}" (${newD.version})`);
    }
    setShowDocModal(false);
  };

  const handleToggleDocStatus = (id) => {
    setDocuments(prev => prev.map(d => {
      if (d.id === id) {
        const next = d.status === 'Published' ? 'Unpublished' : 'Published';
        auditLogAction?.('AI Knowledge CMS', `Changed status of "${d.title}" to ${next}`);
        return { ...d, status: next };
      }
      return d;
    }));
  };

  const handleDeleteDoc = (id, title) => {
    if (window.confirm(`Archive document "${title}"?`)) {
      setDocuments(prev => prev.filter(d => d.id !== id));
      auditLogAction?.('AI Knowledge CMS', `Archived document "${title}"`);
    }
  };

  // ─── FAQ HANDLERS ───
  const openAddFaq = () => {
    setEditingFaq(null);
    setFaqForm({ category: 'General', question: '', answer: '', status: 'Published' });
    setShowFaqModal(true);
  };

  const openEditFaq = (f) => {
    setEditingFaq(f.id);
    setFaqForm({ category: f.category, question: f.question, answer: f.answer, status: f.status });
    setShowFaqModal(true);
  };

  const handleSaveFaq = (e) => {
    e.preventDefault();
    if (editingFaq) {
      setFaqs(prev => prev.map(f => f.id === editingFaq ? { ...f, ...faqForm } : f));
      auditLogAction?.('AI Knowledge CMS', `Updated FAQ "${faqForm.question}"`);
    } else {
      const newF = { id: `faq_${Date.now()}`, ...faqForm };
      setFaqs(prev => [...prev, newF]);
      auditLogAction?.('AI Knowledge CMS', `Created new FAQ "${newF.question}"`);
    }
    setShowFaqModal(false);
  };

  const handleDeleteFaq = (id, q) => {
    if (window.confirm(`Delete FAQ "${q}"?`)) {
      setFaqs(prev => prev.filter(f => f.id !== id));
      auditLogAction?.('AI Knowledge CMS', `Deleted FAQ "${q}"`);
    }
  };

  // ─── SIMULATOR HANDLER ───
  const handleTestSimulator = (e) => {
    e.preventDefault();
    const q = simQuery.toLowerCase();

    if (q.includes('refund') || q.includes('charge')) {
      setSimResponse({
        source: 'doc_refund_sla & doc_pricing_rules (Published v2.2)',
        intent: 'REFUND_INQUIRY_SLA',
        answer: 'Eligible refunds are processed within 48 hours. Booking charge (₹99) and 18% GST are strictly non-refundable according to published policy v2.2.'
      });
    } else if (q.includes('cancel')) {
      setSimResponse({
        source: 'doc_cancel_policy (Published v2.4)',
        intent: 'CANCELLATION_POLICY',
        answer: 'Free cancellation is available up to 1 hour before scheduled time. Base service fee is refunded; booking charge ₹99 is retained.'
      });
    } else if (q.includes('samsung') || q.includes('daikin') || q.includes('dell')) {
      setSimResponse({
        source: 'Master Brand Registry (Admin Approved)',
        intent: 'BRAND_SUPPORT_CHECK',
        answer: 'Yes! BookurTechnician provides specialized repairs and maintenance for supported brand devices.'
      });
    } else {
      setSimResponse({
        source: 'Master Services Catalog & Published FAQs',
        intent: 'GENERAL_SERVICE_QUERY',
        answer: 'Doorstep technical services available across AC, Laptop, Fan, Refrigerator, and Washing Machine categories.'
      });
    }
  };

  return (
    <div className="ai-assistant-cms-view">
      {/* ─── FLAT TABS ─── */}
      <div className="flat-tabs">
        <div className={`flat-tab ${activeTab === 'documents' ? 'active' : ''}`} onClick={() => setActiveTab('documents')}>
          📚 Published Policy Documents ({documents.length})
        </div>
        <div className={`flat-tab ${activeTab === 'faqs' ? 'active' : ''}`} onClick={() => setActiveTab('faqs')}>
          ❓ FAQ Knowledge Base ({faqs.length})
        </div>
        <div className={`flat-tab ${activeTab === 'simulator' ? 'active' : ''}`} onClick={() => setActiveTab('simulator')}>
          🤖 AI Response Simulator & Inspector
        </div>
      </div>

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 1: KNOWLEDGE DOCUMENTS & LEGAL POLICIES
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'documents' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">AI Assistant Policy & Legal Repository</h2>
              <p className="page-subtitle">
                Manage strictly verified source-of-truth documents. Chatbot uses only the latest published version.
              </p>
            </div>
            <button className="btn btn-primary" onClick={openAddDoc}>
              + New Knowledge Document
            </button>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Document Title & Description</th>
                  <th>Version</th>
                  <th>Effective Date</th>
                  <th>Updated By</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {documents.map(d => (
                  <tr key={d.id}>
                    <td>
                      <span className="badge badge-info">{d.category}</span>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--text-main)', fontSize: '14px' }}>{d.title}</strong>
                      <div style={{ fontSize: '12px', color: 'var(--text-secondary)', marginTop: '4px', maxWidth: '380px' }}>
                        {d.content}
                      </div>
                    </td>
                    <td>
                      <strong style={{ color: 'var(--primary)', fontFamily: 'monospace' }}>{d.version}</strong>
                    </td>
                    <td>{d.effectiveDate}</td>
                    <td>
                      <div>{d.updatedBy}</div>
                      <small style={{ color: 'var(--text-secondary)' }}>{d.updatedAt}</small>
                    </td>
                    <td>
                      <span className={`badge ${d.status === 'Published' ? 'badge-completed' : 'badge-cancelled'}`}>
                        {d.status}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                        <button className="btn btn-outline btn-sm" onClick={() => handleToggleDocStatus(d.id)}>
                          {d.status === 'Published' ? 'Unpublish' : 'Publish'}
                        </button>
                        <button className="btn btn-secondary btn-sm" onClick={() => openEditDoc(d)}>
                          Edit
                        </button>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeleteDoc(d.id, d.title)}>
                          Archive
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 2: FAQS
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'faqs' && (
        <div className="panel">
          <div className="page-header-row">
            <div>
              <h2 className="page-title">FAQ Knowledge Base</h2>
              <p className="page-subtitle">
                Controlled question-and-answer pairs served directly to Customer Mobile Chatbot
              </p>
            </div>
            <button className="btn btn-primary" onClick={openAddFaq}>
              + Add FAQ
            </button>
          </div>

          <div className="table-responsive">
            <table className="flat-table">
              <thead>
                <tr>
                  <th>Topic</th>
                  <th>Question & Official Answer</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {faqs.map(f => (
                  <tr key={f.id}>
                    <td><span className="badge badge-info">{f.category}</span></td>
                    <td>
                      <strong style={{ color: 'var(--text-main)', fontSize: '13.5px' }}>{f.question}</strong>
                      <div style={{ fontSize: '12.5px', color: 'var(--text-secondary)', marginTop: '4px' }}>
                        {f.answer}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${f.status === 'Published' ? 'badge-completed' : 'badge-cancelled'}`}>
                        {f.status}
                      </span>
                    </td>
                    <td style={{ textAlign: 'right' }}>
                      <div className="page-actions-group" style={{ justifyContent: 'flex-end' }}>
                        <button className="btn btn-secondary btn-sm" onClick={() => openEditFaq(f)}>
                          Edit
                        </button>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeleteFaq(f.id, f.question)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════════════
          TAB 3: AI SIMULATOR
         ════════════════════════════════════════════════════════════════════════ */}
      {activeTab === 'simulator' && (
        <div className="panel" style={{ maxWidth: '800px' }}>
          <div className="panel-header">
            <h3 className="panel-title">🤖 Live AI Inference Tester</h3>
          </div>
          <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
            Simulate how Bookur Assistant resolves customer questions against currently published policies without hallucinations.
          </p>

          <form onSubmit={handleTestSimulator}>
            <div className="form-group">
              <label className="form-label">Test Customer Query</label>
              <div style={{ display: 'flex', gap: '8px' }}>
                <input
                  type="text"
                  required
                  className="form-control"
                  placeholder="e.g. Is booking fee refundable? / Can I cancel? / Do you service Samsung?"
                  value={simQuery}
                  onChange={e => setSimQuery(e.target.value)}
                />
                <button type="submit" className="btn btn-primary" style={{ flexShrink: 0 }}>
                  Test Query
                </button>
              </div>
            </div>
          </form>

          {simResponse && (
            <div style={{ marginTop: '20px', padding: '16px', background: 'var(--primary-light)', border: '1px solid var(--border-color)', borderRadius: '6px' }}>
              <div style={{ fontSize: '12px', fontWeight: '700', color: 'var(--primary)', marginBottom: '4px' }}>
                VERIFIED KNOWLEDGE SOURCE: {simResponse.source}
              </div>
              <div style={{ fontSize: '11px', color: 'var(--text-secondary)', marginBottom: '8px' }}>
                Classified Intent: <strong>{simResponse.intent}</strong>
              </div>
              <div style={{ padding: '12px', background: 'var(--bg-white)', borderRadius: '4px', border: '1px solid var(--border-color)', fontSize: '13.5px', color: 'var(--text-main)', lineHeight: '1.5' }}>
                {simResponse.answer}
              </div>
            </div>
          )}
        </div>
      )}

      {/* ─── DOCUMENT MODAL ─── */}
      {showDocModal && (
        <div className="modal-overlay" onClick={() => setShowDocModal(false)}>
          <div className="modal-dialog" style={{ maxWidth: '640px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingDoc ? 'Edit Policy Document' : 'Publish Knowledge Document'}</h3>
              <button className="modal-close-btn" onClick={() => setShowDocModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveDoc}>
              <div className="modal-body">
                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Category</label>
                    <select
                      className="form-control"
                      value={docForm.category}
                      onChange={e => setDocForm({ ...docForm, category: e.target.value })}
                    >
                      <option value="Cancellation Policy">Cancellation Policy</option>
                      <option value="Refund Policy">Refund Policy</option>
                      <option value="Service Charges">Service Charges</option>
                      <option value="Technician Information">Technician Information</option>
                      <option value="Terms & Conditions">Terms & Conditions</option>
                      <option value="Privacy Policy">Privacy Policy</option>
                      <option value="Payment Information">Payment Information</option>
                    </select>
                  </div>
                  <div className="form-group">
                    <label className="form-label">Document Version</label>
                    <input
                      type="text"
                      required
                      className="form-control"
                      value={docForm.version}
                      onChange={e => setDocForm({ ...docForm, version: e.target.value })}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label className="form-label">Document Title</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    placeholder="e.g. Standard 1-Hour Free Cancellation Window"
                    value={docForm.title}
                    onChange={e => setDocForm({ ...docForm, title: e.target.value })}
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">Document Body / Verified AI Truth</label>
                  <textarea
                    required
                    rows="5"
                    className="form-control"
                    value={docForm.content}
                    onChange={e => setDocForm({ ...docForm, content: e.target.value })}
                  ></textarea>
                </div>

                <div className="form-row">
                  <div className="form-group">
                    <label className="form-label">Effective Date</label>
                    <input
                      type="text"
                      className="form-control"
                      value={docForm.effectiveDate}
                      onChange={e => setDocForm({ ...docForm, effectiveDate: e.target.value })}
                    />
                  </div>
                  <div className="form-group">
                    <label className="form-label">Publication Status</label>
                    <select
                      className="form-control"
                      value={docForm.status}
                      onChange={e => setDocForm({ ...docForm, status: e.target.value })}
                    >
                      <option value="Published">Published (Active on Chatbot)</option>
                      <option value="Unpublished">Unpublished (Draft)</option>
                    </select>
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowDocModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Document</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ─── FAQ MODAL ─── */}
      {showFaqModal && (
        <div className="modal-overlay" onClick={() => setShowFaqModal(false)}>
          <div className="modal-dialog" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3 className="modal-title">{editingFaq ? 'Edit FAQ' : 'Add FAQ Pair'}</h3>
              <button className="modal-close-btn" onClick={() => setShowFaqModal(false)}>×</button>
            </div>
            <form onSubmit={handleSaveFaq}>
              <div className="modal-body">
                <div className="form-group">
                  <label className="form-label">Topic Category</label>
                  <input
                    type="text"
                    className="form-control"
                    value={faqForm.category}
                    onChange={e => setFaqForm({ ...faqForm, category: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Customer Question</label>
                  <input
                    type="text"
                    required
                    className="form-control"
                    value={faqForm.question}
                    onChange={e => setFaqForm({ ...faqForm, question: e.target.value })}
                  />
                </div>
                <div className="form-group">
                  <label className="form-label">Official Answer</label>
                  <textarea
                    required
                    rows="3"
                    className="form-control"
                    value={faqForm.answer}
                    onChange={e => setFaqForm({ ...faqForm, answer: e.target.value })}
                  ></textarea>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-outline" onClick={() => setShowFaqModal(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save FAQ</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
